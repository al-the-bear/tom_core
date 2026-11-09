# Tom Core Server API Reference: Index

Per-module API summaries for `tom_core_server` — the server layer of Tom Core.
It re-exports all of `tom_core_kernel` (see that package's docs for the kernel
API), `mysql_client`, and `tom_basics_console`, and adds the server-specific
surface documented here.

## Quick Navigation

| Module | Summary | What it provides |
| ------ | ------- | ---------------- |
| Audit | [api_summary_audit.md](api_summary_audit.md) | Attributable, tamper-evident records: the hash-chained trail, its sinks, and signed anchors. |
| Audit Reports | [api_summary_audit_reports.md](api_summary_audit_reports.md) | Questions asked of the audit trail across its writers, saved questions, their scheduled deliveries, and the `/audit-reports` API. |
| Authentication | [api_summary_authentication.md](api_summary_authentication.md) | Login and two-factor services, adaptors, the policy deciding who owes a factor, enrolment and its stores, the authentication server, the server's own self-login, and external identity: the OAuth / OpenID Connect handshake and SAML 2.0 single sign-on, their pending-authorization stores, role mapping, and the linking table; and user provisioning over SCIM 2.0 — the service, its stores and endpoints, and the directory that resolves single sign-on to provisioned accounts; service accounts with their API keys and stores; and browser sessions held in an `HttpOnly` cookie, with the CSRF check they are held to. |
| Authorization | [api_summary_authorization.md](api_summary_authorization.md) | Authorization cache, graded access, principal delegation and resource grants. |
| Cache | [api_summary_cache.md](api_summary_cache.md) | Isolate-backed server cache, its command messages, cross-node invalidation and item-authorization answers. |
| Command Line | [api_summary_cmdline.md](api_summary_cmdline.md) | CLI argument parsing (`TomArgs`) and `.env` file loading (`TomEnvFile`). |
| Configuration | [api_summary_configuration.md](api_summary_configuration.md) | Server config provider, typed config values, YAML resources, secret references resolved from a secret store, and the configured feature flags with their endpoint. |
| Datasources | [api_summary_datasources.md](api_summary_datasources.md) | DB type system, SQL dialects, queries, MariaDB datasource/prepared statements, read replicas. |
| Database Migration | [api_summary_db_migration.md](api_summary_db_migration.md) | Migration runner, versioning, rollback with down scripts, the record of the last run readiness reads, and the MariaDB and PostgreSQL migration adaptors. |
| Endpoints | [api_summary_endpoints.md](api_summary_endpoints.md) | Service/endpoint annotations, routing, handler pipeline, error handling, and the three transports over it: HTML form bodies, redirects and WebSockets — plus the HTTP surface of file columns, idempotency keys that answer a retried request with the first one's response, and the CORS allow-list deciding which browser origins may read a response. |
| Export | [api_summary_export.md](api_summary_export.md) | Tabular results rendered to CSV, XLSX or PDF with charts, stored for later retrieval or sent by email, and the register of stored exports with a per-owner quota and a retention purge. |
| File Storage | [api_summary_file_storage.md](api_summary_file_storage.md) | Streaming blob storage: one put/get contract over memory, directory, database and S3 backends, and a deduplicating store with a per-owner quota in front of any of them. |
| Health Check | [api_summary_healthcheck.md](api_summary_healthcheck.md) | Health analyzer and health-check service/server — process-wide or per instance, with cooperative cancellation of a timed-out analysis — and the framework readiness checks `/ready` answers with by default — or `503 shutting down` once a graceful shutdown has begun. |
| Item Authorization | [api_summary_item_authorization.md](api_summary_item_authorization.md) | Item authorizations kept by an external authority: the port to it, a caching client for checks, accessible items and the user's sharing acts, and the row scope it feeds. |
| Little Things | [api_summary_little_things.md](api_summary_little_things.md) | The server-side base exception `TomServerException`, the `TomLoginFailure` reason its login subclass carries — correlated with the kernel's request id — `tomErrorEnvelope`, the wire shape every error response uses, and `tomErrorResponse`, which answers it as the envelope or as an RFC 9457 problem document. |
| Messaging | [api_summary_messaging.md](api_summary_messaging.md) | Channel-neutral messages, delivery transports (SMTP, HTTP SMS gateway and stand-ins), MIME encoding, the durable outbox, resource-keyed email and SMS, the idempotent receiver (inbox) for consuming a broker's messages once, and the bus relay that publishes to a message bus after the transaction commits. |
| Metrics | [api_summary_metrics.md](api_summary_metrics.md) | The request series, the Prometheus scrape endpoint answered ahead of authentication, and the OTLP/HTTP transport and metrics exporter. |
| Notifications | [api_summary_notifications.md](api_summary_notifications.md) | The notification model above messaging: notification types and their policy, subscription resolution, per-user channel choices, cadences and quiet hours read from the user preferences, resource-keyed rendering, the dispatcher that fans a notification out to the outbox, hourly and daily digests, and `GET /notification-preferences`. |
| Object Persistence | [api_summary_object_persistence.md](api_summary_object_persistence.md) | Persistence annotations, repositories, query builder, operators/expressions, subqueries and association filters, grouped queries and their aggregates, paging and sorting, file-reference columns, data scoping, column authorization, field-level encryption with its keys, rotation and re-encryption, and the entity lifecycle: soft delete, history tables, lifecycle hooks and change events. |
| Preferences | [api_summary_preferences.md](api_summary_preferences.md) | Server-stored per-principal preferences: the scoped `tom_user_preference` entity, the typed service over it, the `/preferences/*` endpoints, and the deployment and role defaults beneath them. |
| Privacy | [api_summary_privacy.md](api_summary_privacy.md) | Data-protection operations: personal-data declarations on entities, erasure, subject-access export, retention, and crypto-shredding of personal values in the audit trail with per-subject keys. |
| Rate Limiting | [api_summary_ratelimit.md](api_summary_ratelimit.md) | Request rate limits per principal, API key or client address: the rules, the sliding-window arithmetic, the per-process and shared limiters, and the middleware answering `429` with `Retry-After`. |
| Resources | [api_summary_resources.md](api_summary_resources.md) | Locale-aware text resolution: one bundle per locale, chosen by the recipient's language. |
| Scheduling | [api_summary_scheduling.md](api_summary_scheduling.md) | The relational half of the job scheduler: the shared job queue, fencing leases, and the node roll call. |
| Server | [api_summary_server.md](api_summary_server.md) | The HTTP server, per-request logging state and correlation ids, middleware, the log format, the paths whose credentials belong to the endpoint, the security headers every response carries, mutual TLS between services, and the graceful shutdown on SIGTERM. |
| Sync | [api_summary_sync.md](api_summary_sync.md) | The server side of the offline sync protocol: exposing an entity under a collection, the change log that numbers every write of it, pushes applied through the entity's repository under optimistic locking, pulls read as the caller, and `POST /sync/push` and `POST /sync/pull`. |
| Tenancy | [api_summary_tenancy.md](api_summary_tenancy.md) | Multi-tenancy: the deployment's tenants, the three isolation models chosen per tenant, data-source routing, and the resolution of a request's tenant from its token, host or header. |
| Tracing | [api_summary_tracing.md](api_summary_tracing.md) | The OpenTelemetry tracer behind the kernel's tracing seam: spans exported over OTLP/HTTP, parent-based sampling, the untraced export client, and an in-memory span exporter for tests. |
| Transactions | [api_summary_transactions.md](api_summary_transactions.md) | Distributed transaction manager and participants, the recovery of prepared branches a dead process left — the decision log and the recovery — and sagas: work across services as local transactions undone by compensations, their orchestrator, stores and table. |

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
| `TomAuditQuery` / `TomAuditQueryResult` | classes | A question about a stored trail, and what it found. |
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
| `TomAuditAnchorMonitor` | class | Verifies each declared chain against the latest anchor published for it. |
| `TomAuditWatchedChain` | class | One chain the deployment declares, and the read it supplies for it. |
| `TomAuditChainReader` | typedef | Reads back the retained entries of one chain, oldest first. |
| `TomAuditAnchorCheck` | class | What one declared chain's check concluded. |
| `TomAuditAnchorCheckFailure` | enum | Why a declared chain produced no verification at all. |
| `TomAuditAnchorReport` | class | What one round of anchor verification concluded. |
| `TomAuditAnchorVerificationJob` | class | The scheduled job that runs a verification round hourly. |
| `TomAuditWriteOnceCheck` | class | What a deployment's audit table actually permits, as observed. |
| `TomAuditTrailRow` | class | One row of the audit trail table. |
| `TomAuditHeadRow` | class | The columns projected when recovering a chain head. |
| `TomAuditSeqRow` | class | A projected sequence number, for retention boundaries. |
| `TomAuditTriggerRow` | class | One `information_schema.TRIGGERS` row. |
| `verifyAuditChain` / `verifyAgainstAnchor` | top-level | Chain and anchor verification. |
| `filterAuditEntries` / `auditProjectionPrefix` | top-level | Answering a query over entries in hand; cutting a value to a projection column's width. |
| `parseAuditLines` / `auditDiff` | top-level | JSON-Lines parsing; the changed-fields pair. |
| `tomAuditGenesisHash` / `tomAuditRedactedPlaceholder` | top-level | The chain start hash; the redaction placeholder. |
| `defaultAuditTrailTable` / `auditTrailTable` / `auditTrailTableDdl` | top-level | The trail table's name, descriptor and DDL. |
| `auditTrailNoUpdateTriggerName` / `auditTrailNoDeleteTriggerName` | top-level | Names of the write-once guard triggers. |
| `auditTrailNoUpdateTriggerDdl` / `auditTrailNoDeleteTriggerDdl` | top-level | MariaDB DDL for the write-once guard triggers. |
| `auditTrailGuardStatements` | top-level | The statements installing one write-once guard in a given dialect's database. |

### Audit Reports (`lib/src/tomserver/audit_reports/`)

Summary: [api_summary_audit_reports.md](api_summary_audit_reports.md)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomAuditQuestion` | class | A saved question. |
| `TomAuditQuestionFilter` | class | What a question asks: the record fields it narrows to and the window. |
| `TomAuditQuestionRow` | class |  |
| `TomAuditQuestionStore` | abstract class | The saved questions. |
| `TomAuditReportDelivery` | class | What one delivery did. |
| `TomAuditReportException` | class | Raised when a question cannot be read, saved, found or answered; [key] names which (`audit_reports.question.invalid`, `audit_reports.question.not_found`, …). |
| `TomAuditReports` | class | Answers, keeps and delivers audit questions. |
| `TomAuditReportsErrorHandler` | class | Maps the audit-report refusals to their statuses: a question that is not the caller's (or not there) is a `404`, one that cannot be read a `400`, one with nowhere to deliver to a `409`, a server that is not set up for audit reports a `503`. |
| `TomAuditReportsServer` | class | The implementation of `tomAuditReportsApi`, over the installed [TomAuditReports]. |
| `TomAuditTrailSource` | abstract class | Where a view reads: the writers a trail holds, and one writer's answer. |
| `TomAuditView` | class | Answers a question across the writers of a trail. |
| `TomAuditViewEntry` | class | One record of a view's answer, with the writer whose chain holds it. |
| `TomAuditViewResult` | class | A view's answer. |
| `TomAuditWriterRow` | class |  |
| `TomMemoryAuditQuestionStore` | class | [TomAuditQuestionStore] in memory. |
| `TomMemoryAuditTrailSource` | class | [TomAuditTrailSource] over in-memory sinks, one per writer — for tests and a single process. |
| `TomSqlAuditQuestionStore` | class | [TomAuditQuestionStore] over the `tom_audit_question` table. |
| `TomSqlAuditTrailSource` | class | [TomAuditTrailSource] over the relational trail: one table, every writer's rows. |
| `auditQuestionTable` | function | The saved-question table, as the framework declares it. |
| `auditQuestionTableDdl` | function | The `CREATE TABLE` of [auditQuestionTable]. |
| `tomAuditReportsDatasource` | function | The data source registered as [name], for the `.named` constructors of this module; refuses (`audit_reports.<part>.unknown_datasource`) a name the registry does not hold. |

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
| `TomWebAuthn2FAService` | class | Passkeys as a second factor, verified by signature; offered once a relying party is configured. |
| `TomWebAuthnVerifier` | abstract final class | The WebAuthn registration and assertion checks as pure functions. |
| `TomWebAuthnRegisteredCredential` | class | A credential a registration verified. |
| `TomWebAuthnVerifiedAssertion` | class | An assertion that verified, with its new counter. |
| `TomWebAuthnSoftwareAuthenticator` | class | A passkey authenticator in software, for tests and bring-up only. |
| `Tom2FAPolicy` | abstract class | Decides, per login, whether a second factor is owed and which mechanisms may satisfy it. |
| `Tom2FARequirement` | enum | How strongly a factor is owed: `disabled`, `optional`, `required`. |
| `Tom2FADecision` | class | One policy verdict: requirement, permitted mechanisms, grace logins left. |
| `TomPrincipalFlag2FAPolicy` | class | The default policy: reads `TomPrincipal.requires2FA` / `twoFactorType`. |
| `TomRole2FAPolicy` | class | Policy driven by role rules, folded to the strictest match. |
| `Tom2FAGraceAccounting` | abstract class | Optional bean that records a grace login being spent. |
| `Tom2FAGraceStore` | abstract class | Where spent grace is remembered, so a budget counts down. |
| `TomMemory2FAGraceStore` | class | The default grace store — a map in this process. |
| `Tom2FAEnrolmentStore` | abstract class | Where a principal's set-up factors live; deployment-supplied, no fallback. |
| `Tom2FAAttemptStore` | abstract class | Records that an interim token has been answered, so a replay cannot mint a fresh allowance. |
| `Tom2FAAttempt` | class | One presentation of an interim token, as an attempt store is told about it. |
| `Tom2FAMemoryAttemptStore` | class | The default attempt store — a map in this process. |
| `Tom2FASend` | class | One request to send a delivered code, with the pace the service asks for. |
| `Tom2FASendLimiter` | abstract class | Paces the codes sent to one address: each later code waits twice as long, up to a cap; proof ends the run. |
| `Tom2FAMemorySendLimiter` | class | The default send limiter — a map in this process. |
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
| `TomLoginException` | class | Login failure (extends `TomServerException`), carrying a `TomLoginFailure` reason. |
| `TomServerSelfLogin` | class | Logs the deployment in as itself, installs the server principal, and renews it before its token expires. |
| `TomServerSession` | class | What a self-login produced: the principal, and when its tokens expire. |
| `TomServiceCredential` | class | The deployment's own login credential and where to present it. |
| `TomServiceLoginTransport` | abstract class | The one-JSON-POST seam the self-login runs over. |
| `TomHttpServiceLoginTransport` | class | The live transport, over `TomServerChannel`. |
| `TomServiceLoginResponse` | class | The raw status + body of a self-login POST. |
| `TomServerSelfLoginException` | class | A configured deployment failed to log itself in. |
| `TomOAuthAuthenticationService` | class | An authentication service for authorization-code logins; delegates every other credential. |
| `TomOAuthCredential` | class | The code + state pair carried in `TomAuthenticationData.key`. |
| `TomExternalIdentityDirectory` | abstract class | What the deployment supplies: local account lookup and first-login provisioning. |
| `TomOAuthProviderConfig` | class | One provider as data: endpoints (or discovery), client credentials, claim names, provisioning, role mapping, clock-skew tolerance. |
| `TomOAuthProviders` | class | The configured provider set, read from `oauth.providers`. |
| `TomOAuthProvisioning` | enum | What a first external login with no local account does: `refuse`, `linkExisting` or `autoProvision` (the default). |
| `TomOAuthFlow` | class | The authorization-code + PKCE handshake with an OpenID Connect nonce; dispatches SAML provider ids to `TomSamlFlow`. |
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
| `TomExternalIdentity` | class | What the provider asserted: issuer, subject, username, display name, claims, groups and mapped roles. |
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
| `TomExternalProvider` | abstract interface class | What every external identity provider has in common: id, issuer, provisioning, role mapping, clock skew. |
| `TomExternalRoleMapping` | class | How a provider's group claim becomes Tom roles, recomputed on every login. |
| `TomExternalTenancyMapping` | class | Which claims of a provider name the tenant and the sign-in organization. |
| `TomSignInOrganization` | class | One organization a principal may sign in for. |
| `TomOrganizationFallback` | enum | Refuse a non-member organization at sign-in, or use the default. |
| `TomSignInOrganizations` | class | A principal's organizations, the default, whether a choice is offered; `settle`. |
| `TomSignInOrganizationDirectory` | abstract interface class | The deployment's hook: list a principal's organizations, sign it in for one. |
| `applyExternalRoles` | top-level function | Adds mapped roles to a principal for this session, beside its own. |
| `TomSamlProviderConfig` | class | One SAML 2.0 identity provider and this server's side of the trust. |
| `TomSamlProviders` | class | The configured SAML providers, read from `saml.providers`; `load` fetches their metadata. |
| `TomSamlIdpMetadata` | class | What an identity provider's metadata document says: entity id, SSO address, signing certificates. |
| `TomSamlCertificates` | abstract final class | Reads the certificates and keys a SAML configuration names. |
| `TomSamlNames` | abstract final class | SAML 2.0 namespace and binding identifiers. |
| `TomSamlFlow` | class | SAML 2.0 Web Browser SSO: the request out, the response in, the handoff to the application. |
| `TomSamlResponseValidator` | class | Verifies a SAML response for one provider and answers the identity it asserts. |
| `TomXmlSignatureVerifier` | class | Verifies an enveloped XML signature against the configured keys only. |
| `TomExclusiveCanonicalizer` | abstract final class | Exclusive XML Canonicalization 1.0, without comments. |
| `TomXmlDsig` | abstract final class | XML Signature namespace and algorithm identifiers. |
| `TomSamlService` | abstract class | The `POST /saml/acs` and `GET /saml/metadata/<providerId>` endpoints (`@tomService`). |
| `TomSamlServer` | class | The default SAML endpoint component. |
| `TomSamlException` | class | A SAML message, configuration value or signature that cannot be used (extends `TomServerException`). |
| `TomOAuthException` | class | A mis-configured provider set or a refused handshake (extends `TomServerException`). |
| `Tom2FAPrerequisite` | abstract class | What an adaptor implements when it works only if something else was installed — a mail service, an SMS gateway, a push credential. |
| `installJwtSigning` | top-level function | Installs the configured JWT key material at boot; refuses the bundled sample keys outside development. |
| `verifyBearerToken` | top-level function | Checks an inbound token's signature against the deployment's own key and returns it decoded, or `null` when this deployment did not issue it. |
| `TomSigningKeyException` | class | The refusal: names the unset key fields and their environment variables (extends `TomServerException`). |
| `TomJwtAlgorithm` | enum | The token signing algorithms a deployment may configure: `rs256` (the default), `es256`, `hs256`. |
| `TomJwtKey` | class | One key a token can be verified with, under its `kid` — the RFC 7638 thumbprint of its public JWK. |
| `TomJwtSigningKey` | class | A signing key and the public key it publishes. |
| `TomJwtSigning` | class | How this process signs and verifies tokens: algorithm, keys, signing key id, issuer, audience. |
| `TomScimSchemas` | abstract final class | The SCIM schema and message URNs. |
| `TomScimResourceType` | enum | `user` or `group`: name, endpoint, schema and name attribute. |
| `TomScimException` | class | A SCIM request that cannot be served, with its HTTP status and `scimType` (extends `TomServerException`). |
| `TomScimResource` | class | One provisioned user or group: id, JSON document, lifecycle instants, change counter. |
| `TomScimStore` | abstract interface class | Where provisioned resources are kept. |
| `TomMemoryScimStore` | class | In-memory SCIM store, per process. |
| `TomSqlScimStore` | class | SCIM store over `tom_scim_resource`, shared by every node and routed per tenant. |
| `TomTenantProviderSets` | class | External-identity provider sets keyed by tenant: `TomOAuthProviders.tenants`, `TomSamlProviders.tenants`. |
| `TomScimResourceRow` | class | One `tom_scim_resource` row, as the SQL store reads it back. |
| `scimResourceTable` / `scimResourceTableDdl` | top-level function | The `tom_scim_resource` declaration, and its `CREATE TABLE`. |
| `defaultScimResourceTable` | constant | `tom_scim_resource`. |
| `TomScimPath` | class | A PATCH attribute path: schema URN, attribute, value filter, sub-attribute. |
| `TomScimFilter` | sealed class | A parsed SCIM filter expression. |
| `TomScimAnd` / `TomScimOr` / `TomScimNot` | class | The logical filter operators. |
| `TomScimValuePath` | class | `attr[filter]` — some element of a multi-valued attribute matches. |
| `TomScimComparison` | class | `attr op value`, or `attr pr`. |
| `scimValues` / `scimLookup` / `scimKeyOf` | top-level function | Case-insensitive reads of a SCIM JSON document. |
| `TomScimService` | class | The SCIM service provider over a store, and the revocations deprovisioning makes. |
| `TomScimProvisioning` | class | The installed SCIM service and the bearer secrets that may call it, read from `scim`. |
| `TomScimApi` | abstract class | The SCIM 2.0 endpoints under `/scim/v2` (`@tomService`). |
| `TomScimServer` | class | The default SCIM endpoint component, in `application/scim+json`. |
| `TomScimIdentityDirectory` | class | Single sign-on over the provisioned users, with roles from their groups. |
| `TomJwtKeyException` | class | A key or signing setting that cannot be used (extends `TomServerException`). |
| `readPemFile` | top-level function | Reads a configured PEM key file, naming it in the error a missing file raises. |
| `TomJwksService` | abstract class | The `GET /.well-known/jwks.json` endpoint (`@tomService`). |
| `TomJwksServer` | class | The default JSON Web Key Set component; publishes `TomJwtSigning.current`'s keys. |
| `TomServiceAccount` | class | A non-human caller with roles of its own. |
| `TomApiKey` | class | One API key's stored record — the hash of its secret, never the secret. |
| `TomIssuedApiKey` | class | A key as issued: the record and the one-time `tomk.<keyId>.<secret>` value. |
| `TomApiKeyIdentity` | class | The key and account a request authenticated with, in the request zone. |
| `TomApiKeyStore` | abstract class | Where service accounts and key records live. |
| `TomMemoryApiKeyStore` | class | In-memory API-key store, per process. |
| `TomSqlApiKeyStore` | class | API-key store over `tom_service_account` and `tom_api_key`, shared by every node. |
| `TomServiceAccountRow` / `TomApiKeyRow` | class | One row of each table, as the SQL store reads it back. |
| `serviceAccountTable` / `apiKeyTable` | top-level function | The two tables' declarations. |
| `defaultServiceAccountTable` / `defaultApiKeyTable` | constant | `tom_service_account` and `tom_api_key`. |
| `TomApiKeys` | class | Issues, rotates, revokes and checks API keys; installed once per process. |
| `TomApiKeyException` | class | An API-key operation that cannot be done (extends `TomServerException`). |
| `TomSessionCookie` | final class | A browser session's access token in an `HttpOnly` cookie, and the double-submit CSRF check a cookie-authenticated request is held to; set from the `sessionCookie` key. |
| `TomSameSite` | enum | The `SameSite` attribute of the session cookies: `strict`, `lax`, `none`. |
| `TomSessionCookieException` | class | The `sessionCookie` settings cannot be applied, or a cookie-authenticated request failed the CSRF check (extends `TomServerException`). |

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
| `TomCacheInvalidation` | class | One invalidation as it travels between nodes: kind, target, key, instant, origin. |
| `TomInvalidationKind` | enum | `principal`, `cacheEntry`, `cache`, `item`. |
| `TomInvalidationChannel` | abstract interface class | How invalidations reach the other nodes; states its `stalenessBound`. |
| `TomLocalInvalidationChannel` | class | The default single-process channel; staleness bound zero. |
| `TomSqlInvalidationChannel` | class | Channel over a polled database table; staleness bound is the poll interval. Also a `TomInvalidationLog`. |
| `TomBusInvalidationChannel` | class | Channel over a `TomMessageBus`, a group of its own per node, ephemeral; staleness bound stated, one second by default. |
| `TomInvalidationLog` | abstract interface class | Where the bus channel remembers the revocations still in force. |
| `TomMemoryInvalidationLog` | class | An invalidation log in memory, for one process and tests. |
| `tomInvalidationTopic` | constant | `tom.cache.invalidation` — the bus channel's default topic. |
| `TomCacheInvalidator` | abstract final class | Cluster-wide entry point: `revokePrincipal`, `invalidateCacheEntry`, `invalidateCache`, `invalidateItemAuthorization`, `install`. |
| `TomCacheInvalidateMessage` | class | Cross-isolate invalidation command (extends `TomCommand`). |
| `TomCacheInvalidationRow` | class | One row of the invalidation log, as the SQL channel reads it. |
| `invalidationTable` | function | The invalidation log, declared once as a framework-owned table. |
| `invalidationTableDdl` | function | The `CREATE TABLE` for it, for a deployment that applies DDL by hand. |
| `defaultInvalidationTable` | constant | `tom_cache_invalidation`. |
| `tomCacheLookupsMetric` | constant | `tom_cache_lookups` — the counter of cache reads by `cache` and `result`. |
| `TomItemAuthorizationCache` | abstract final class | The answers a remote authority gave on items, keyed by item and subject. |
| `TomCachedItemLevel` | class | One cached answer: the level held, or none. |
| `TomItemAuthorizationChange` | class | One change an authority reports: an item and, for one user, that user. |
| `TomItemAuthorizationChangePage` | class | One answer of the change feed: changes, next cursor, more waiting. |
| `TomItemAuthorizationWebhook` | class | Verifies an `itemAuthorization.changed` delivery and drops the answers it names. |
| `TomItemAuthorizationFeedFollower` | class | Reads the change feed on a timer, the catch-up for lost deliveries. |
| `TomItemAuthorizationWebhookException` | class | A webhook delivery that cannot be trusted or read (extends `TomServerException`). |
| `TomItemAuthorizationFeedExpiredException` | class | The feed no longer holds the cursor (extends `TomServerException`). |

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
| `isDevelopmentOrTestRuntime` | top-level function | Whether the current runtime environment is a development or test one; a boot that declared none is neither. |
| `TomSecrets` | abstract final class | The registered secrets providers and the secrets resolved through them: load, substitute, refresh, watch. |
| `TomSecretsProvider` | abstract class | A secret store, registered under the name `secret:<provider>:…` references use. |
| `TomMapSecretsProvider` | class | A provider answering from a map, for tests and local development. |
| `TomSecretReference` | class | A parsed `secret:<provider>:<path>[#<field>]` reference. |
| `TomSecretPayload` | class | What a provider read for one path. |
| `TomSecretSubscription` | class | A watcher's registration, ended by `cancel`. |
| `TomSecretsRefresh` | class | What one refresh found: changed and failed references. |
| `TomSecretsException` | class | A secret that could not be read or resolved (extends `TomServerException`). |
| `TomFeatureFlagsServer` | class | The `featureFlags` configuration key, installed as the flag provider, and the `GET /feature-flags` endpoint. |

### Datasources (`lib/src/tomserver/datasources/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomDbType<T>` | abstract class | Base DB column type (extends kernel `TomObject`). |
| `TomDbInt` / `TomDbDouble` / `TomDbString` / `TomDbDateTime` / `TomDbDate` / `TomDbTime` / `TomDbBool` | class | Concrete DB types. |
| `TomOperator<R>` | abstract class | Base of the SQL expression tree. |
| `TomStandardSqlDialect` | class | Standard-SQL dialect. |
| `MariadbSqlDialect` | class | MariaDB dialect. |
| `PostgresSqlDialect` | class | PostgreSQL dialect: canonical DDL translated, truth values, `ON CONFLICT`, `RETURNING`. |
| `TomQuery` / `TomGeneratedQuery` | abstract class | Query base types. |
| `TomSelect` / `TomLiteralSelect` / `TomCount` / `TomDelete` / `TomUpdate` | class | Concrete queries; `TomUpdate` is what a repository renders a soft delete and a restore as. |
| `TomTypePersistenceInfo` | class | Type persistence metadata. |
| `TomTypedPersistenceBase` | abstract class | Base for typed persistence. |
| `TomDataSource` | abstract class | Datasource contract (a transaction participant). |
| `TomPreparedStatement<T>` | abstract class | Prepared-statement contract. |
| `TomStatementOutcome<T>` | class | What one execution of a prepared statement reported — its rows, the rows it changed and the key it generated — returned by that execution rather than kept on the shared handle. |
| `TomDataSourceInfo` | class | Datasource descriptor. |
| `TomDatasourceDriver` | class | Annotation tagging a driver. |
| `TomSqlDatasource` | abstract class | The driver-neutral SQL data source: pool, transaction branches, statement paths, row mapping, settings binding, and the database-wide session lock. |
| `TomSqlPreparedStatement<T>` | class | A prepared statement of a `TomSqlDatasource`, prepared on each pooled connection that runs it. |
| `TomSqlRow` | abstract interface class | One result row, every column read as text in one convention. |
| `TomSqlResult` | abstract interface class | What a statement produced: rows, affected-row count, generated key. |
| `TomSqlResultValues` | class | A `TomSqlResult` holding its values. |
| `TomSqlLink` | abstract class | One pooled connection of a `TomSqlDatasource`. |
| `TomSqlBranch` | class | One transaction's share of a data source: its pinned connection and two-phase branch. |
| `TomSqlTwoPhaseRecovery` | mixin | A two-phase driver's part in recovery: the branch it prepared, and its database's prepared branches listed and resolved. |
| `MariaDbDatasource` | class | MariaDB datasource over a connection pool. |
| `MariaDbXADatasource` | class | XA-capable MariaDB datasource. |
| `MariadbPreparedStatement<T>` | class | MariaDB prepared statement, prepared on each pooled connection that runs it. |
| `PostgresDatasource` | class | PostgreSQL 15+ datasource over a connection pool. |
| `PostgresXADatasource` | class | PostgreSQL datasource taking part in two-phase commits. |
| `TomConnectionPool<C>` | class | A bounded pool of connections of any driver's type; a connection per transaction. |
| `TomConnectionPoolSettings` | class | How a pool sizes itself and when it retires a connection. |
| `TomConnectionFactory<C>` | abstract interface class | What a driver tells the pool about its connection type: open, close, check, validate. |
| `TomReplicaRouting` | abstract final class | The read-replica routing rules: read-only work, read statements, repository reads, and the blocks that mark or override them. |
| `TomPrimaryReads` | class | Annotation pinning an entity's reads to the primary, never a read replica. |
| `SqlPlaceholderScan` | class | SQL placeholder scanner. |
| `TomSqlLexer` | class | The package's one quote/comment scanner and statement splitter. |
| `TomFrameworkTable` | class | The single declaration of a table the framework itself owns. |
| `TomFrameworkColumn` | class | One column of a framework-owned table. |
| `TomFrameworkKey` | class | One index or unique constraint of a framework-owned table. |
| `TomSchemaProvisioning` | class | Creates a store's tables at most once, however many first calls arrive together. |
| `TomDatasourceInitException` | class | Init error (extends `TomServerException`). |
| `TomSqlDatasourceException` | class | A SQL data-source failure (extends `TomServerException`). |
| `TomSqlConnectionLostException` | class | A statement lost its connection; raising it is the decision to retry once (extends `TomServerException`). |
| `MariadbDatasourceException` | class | MariaDB error (extends `TomSqlDatasourceException`). |
| `MariadbPreparedStatementException` | class | MariaDB lost-connection signal (extends `TomSqlConnectionLostException`). |
| `PostgresDatasourceException` | class | PostgreSQL error (extends `TomSqlDatasourceException`). |
| `PostgresConnectionLostException` | class | PostgreSQL lost-connection signal (extends `TomSqlConnectionLostException`). |
| `TomConnectionPoolException` | class | The pool is closed, timed out waiting, or misconfigured (extends `TomServerException`). |
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
| `parseSqlDate` | function | Reads a stored `DATE` back as a `TomZonedDate` — the reading half of `sqlDate`. |
| `parseSqlTimeOfDay` | function | Reads a stored `TIME` back as a `TomZonedTime` — the reading half of `sqlTimeOfDay`. |
| `parseSqlInstant` | function | Reads a stored `DATETIME(6)` back as a UTC `DateTime`. |
| `parseOptionalSqlInstant` | function | The same, treating an empty column as absent. |
| `unknownFrameworkColumns` | function | Audits a statement for column references no framework table declares. |
| `tomSqlBindValue` | function | Marshals one bind value into the primitive every SQL driver binds. |
| `tomSqlBindParams` | function | A parameter map with every value marshalled through `tomSqlBindValue`. |
| `tomSqlBranchId` | function | A bounded, process-unique two-phase branch id. |
| `tomSqlOwnsBranch` | function | Whether a branch id is one `tomSqlBranchId` built for a data source's coordinates. |
| `tomSqlBranchOpenedAt` | function | When a `tomSqlBranchId` was opened, read from the id. |
| `tomDbStatementDurationMetric` / `tomDbStatementErrorsMetric` / `tomDbPoolConnectionsMetric` / `tomDbPoolAcquireDurationMetric` / `tomDbPoolAcquireFailuresMetric` | constant | The names of the statement and pool series every `TomSqlDatasource` records. |

### Database Migration (`lib/src/tomserver/db_migration/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomDbMigrations` | class | Migration runner/registry; the migration lock by data-source name, the repair of a failed migration and the rollback of applied ones, from code or the command line. |
| `TomDbMigrator` | abstract class | Migrator contract, including the migration lock, the repair of a failed record and the rollback. |
| `TomDbMigrationAdaptor` | class | Annotation tagging a migration adaptor with the data-source types it serves. |
| `TomMigrationScript` | class | One migration's up and down scripts, as a rollback reads them. |
| `TomSqlMigrationAdaptor` | abstract class | The database-neutral SQL migrator: versioning history, checksums, rebinding, the migration lock, repair and rollback. |
| `MariadbMigrationAdaptor` | class | MariaDB migration adaptor (`mariadb`, `mariadb_xa`). |
| `PostgresMigrationAdaptor` | class | PostgreSQL migration adaptor (`postgresql`, `postgresql_xa`); a script and its version row in one transaction. |
| `TomMigrationFileName` | class | Parses/validates migration file names. |
| `TomDbVersion` | class | A schema version. |
| `TomMigrationRun` | class | The process's most recent `migrateDatabases` call (`TomDbMigrations.lastRun`). |
| `TomMigrationRunState` | enum | `notRun`, `running`, `succeeded` or `failed`. |
| `TomMigrationRepair` | enum | What repair does with a failed migration: `remove` it or `markResolved`. |
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
| `TomSqlMigrationException` | class | SQL migration error (extends `TomServerException`). |
| `MariadbMigrationException` | class | MariaDB migration error (extends `TomSqlMigrationException`). |
| `PostgresMigrationException` | class | PostgreSQL migration error (extends `TomSqlMigrationException`). |

### Endpoints (`lib/src/tomserver/endpoints/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomService` | class | Service annotation (`@tomService`, or `@TomService(version:, problemJson:)` for a versioned service or one answering problem+json). |
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
| `TomStatusMappingErrorHandler` | class | Error handler answering the framework envelope at a declared per-key status. |
| `TomDefaultErrorHandler` | class | Default error handler: the envelope, always `500`. |
| `TomEndpointHandlerException` | class | Handler error. |
| `TomEndpointPipelineException` | class | Pipeline error. |
| `TomCors` | final class | Which browser origins may read a response: an allow-list, empty by default; set from the `cors` key. |
| `TomCorsException` | class | The `cors` settings cannot be applied (extends `TomServerException`). |
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
| `TomOpenApiService` | abstract class | The public route contract for the server's OpenAPI document, `GET /openapi.json`. |
| `TomOpenApiServer` | class | Serves the build-generated OpenAPI document the configuration points at. |
| `TomIdempotent` | class | Method annotation: requests may carry an `Idempotency-Key`. |
| `TomIdempotencyException` | class | A key that cannot be used, a store without its data source, or an `idempotency` configuration of the wrong shape. |
| `TomIdempotencyScope` | class | Whose key it is: tenant, principal, operation and key. |
| `TomIdempotencyRecord` | class | A stored request's fingerprint and, once finished, its response. |
| `TomIdempotencyClaim` | class | The outcome of a claim: won, or lost to a record. |
| `TomIdempotencyStore` | abstract class | Where idempotency records are kept. |
| `TomMemoryIdempotencyStore` | class | The records of one process, in memory; the default. |
| `TomSqlIdempotencyStore` | class | The records in a SQL table, shared by every instance; its data source resolved by name per call. |
| `TomIdempotencyRow` | class | One row of the idempotency table, as the SQL store reads it. |
| `TomIdempotency` | abstract final class | The isolate's idempotency settings, and `handle`, which answers one request. |
| `defaultIdempotencyTable` | constant | `tom_idempotency_key`. |
| `idempotencyTable` | function | The idempotency table, declared once. |
| `idempotencyTableDdl` | function | The `CREATE TABLE` for it, for a deployment that applies DDL by hand. |

### Export (`lib/src/tomserver/export/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomTabularResult` | class | A complete result: title, metadata, and one or more sections. |
| `TomTabularSection` | class | One titled table: typed columns over a stream of rows. |
| `TomTabularColumn` | class | One typed column: machine key, human label, type. |
| `TomTabularRow` | class | One row: cell values positional to the columns. |
| `TomColumnType` | enum | The value types a column may hold. |
| `TomTabularChart` | class | A bar, line or pie chart of a section's own rows, naming its columns. |
| `TomChartType` | enum | The kinds of chart: bar, line, pie. |
| `TomTabularRenderer` | abstract class | Renders a result to a byte stream in one format. |
| `TomCsvRenderer` | class | RFC 4180 CSV, one row at a time. |
| `TomXlsxRenderer` | class | Office Open XML workbook, one worksheet per section. |
| `TomPdfRenderer` | class | Paginated PDF with title, metadata block and tables. |
| `TomExportFormats` | class | The set of formats an application offers. |
| `TomExportStore` | abstract class | Stores and retrieves rendered exports by key. |
| `TomExportStoreOperation` | enum | The five store operations and the error key each failure carries. |
| `TomDirectoryExportStore` | class | Export store over a local directory tree. |
| `TomMemoryExportStore` | class | In-memory export store, for tests. |
| `TomBlobExportStore` | class | Export store backed by a `TomBlobStore`. |
| `TomStoredExport` | class | What was written, where, and how big it turned out. |
| `TomExportService` | class | The seam an endpoint calls: render, optionally store, record and enforce a quota. |
| `TomExportEmailDelivery` | class | The email channel: a stored export sent as a link or an attachment through the outbox. |
| `TomExportEmailMode` | enum | Link, attach, or attach up to a size and link beyond. |
| `TomExportRegister` | abstract class | The record of stored exports: who, how large, when. |
| `TomMemoryExportRegister` | class | In-memory register, for tests and a single process. |
| `TomSqlExportRegister` | class | The register in a SQL table, `tom_export`. |
| `TomExportRecord` | class | One stored export as the register knows it. |
| `TomExportUsage` | class | What one owner holds: a count and a byte total. |
| `TomExportRecordRow` | class | One row of the register table, as the SQL register reads it. |
| `TomExportUsageRow` | class | The aggregate row the SQL register's usage query reads. |
| `TomExportQuota` | class | How many exports, and bytes, one owner may hold. |
| `TomExportRetention` | class | Deletes exports older than a maximum age; also as a scheduled job. |
| `TomExportException` | class | Export failure (extends `TomServerException`). |
| `defaultExportRegisterTable` | constant | `tom_export`. |
| `exportRegisterTable` | function | The register table, declared once. |
| `exportRegisterTableDdl` | function | The `CREATE TABLE` for it, for a deployment that applies DDL by hand. |
| `tomFormatCellAsText` | top-level | The shared text rule for the text-oriented renderers. |

### File Storage (`lib/src/tomserver/file_storage/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomBlobStore` | abstract class | Stores and retrieves blobs by key, streaming. |
| `TomStoredBlob` | class | A stored blob: key, content type, size. |
| `TomBlobRange` | class | A half-open byte range of a blob, for a partial read. |
| `TomBlobDigest` | class | The running SHA-256 a backend feeds while it writes. |
| `TomMemoryBlobStore` | class | In-memory blob store, for tests and development. |
| `TomDirectoryBlobStore` | class | Blob store over a local directory tree. |
| `TomDatabaseBlobStore` | class | Blob store over a manifest and chunk table pair. |
| `TomS3BlobStore` | class | Blob store over an S3-compatible object store. |
| `TomBlobStoreInfo` | class | The process-wide registry of named, configured stores. |
| `TomBlobStoreBackend` | abstract class | One backend: its settings as fields, and the store they build. |
| `TomMemoryBlobStoreBackend` / `TomDirectoryBlobStoreBackend` / `TomDatabaseBlobStoreBackend` / `TomS3BlobStoreBackend` | class | The four built-in backends, registered as `memory`, `directory`, `database` and `s3`. |
| `TomBlobStoreBackendFactory` | typedef | Creates a fresh backend of one type. |
| `TomAwsV4Signer` | class | Signs HTTP requests with AWS Signature Version 4. |
| `TomAwsCredentials` | class | The key pair, optionally with a session token. |
| `TomAwsCredentialsSource` | typedef | Supplies the credentials of each AWS request; used by the AWS secrets provider and the AWS message bus. |
| `TomBlobManifestRow` | class | One row of the blob manifest table. |
| `TomBlobChunkRow` | class | One chunk row's payload. |
| `TomStorageException` | class | Storage failure (extends `TomServerException`). |
| `TomBlobStoreOperation` | enum | The four operations a storage failure is reported as. |
| `defaultBlobManifestTable` / `defaultBlobChunkTable` | top-level | Default table names. |
| `blobManifestTable` / `blobChunkTable` | top-level | The table descriptors. |
| `blobManifestTableDdl` / `blobChunkTableDdl` | top-level | The `CREATE TABLE` statements, for a deployment that applies its own schema. |
| `TomDeduplicatingBlobStore` | class | A store in front of another keeping one copy per content, a quota per owner, and the reclaim of content no key names. |
| `TomBlobLedger` | abstract class | The record of keys, owners and contents a deduplicating store keeps. |
| `TomMemoryBlobLedger` / `TomSqlBlobLedger` | class | That record in memory / in `tom_blob_ledger` and `tom_blob_content`. |
| `TomBlobLedgerEntry` / `TomBlobContent` | class | One logical key / one distinct content of the ledger. |
| `TomBlobQuota` / `TomBlobUsage` | class | The most one owner may hold, and what it holds. |
| `TomBlobLedgerEntryRow` / `TomBlobContentRow` / `TomBlobUsageRow` / `TomBlobReferenceCountRow` | class | The rows the SQL ledger reads. |
| `defaultBlobLedgerTable` / `defaultBlobContentTable` | top-level | The ledger's default table names. |
| `blobLedgerTable` / `blobContentTable` | top-level | The ledger's table descriptors. |
| `blobLedgerTableDdl` / `blobContentTableDdl` | top-level | Their `CREATE TABLE` statements. |
| `tomBlobKeyUnder` | top-level | Whether a key is a prefix or lies below it, by segment. |

### Health Check (`lib/src/tomserver/healthcheck/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomHealthAnalyzer` | abstract class | Health-analysis contract. |
| `TomHealthCheck` | class | One analysis in progress: its probe, its deadline, and whether the probe has given up. |
| `TomHealthCheckCancelled` | class | Thrown by `TomHealthCheck.throwIfCancelled` once the probe has given up. |
| `TomHealthStatus` | class | A verdict a probe acts on, and a message a human reads. |
| `TomHealthVerdict` | enum | `healthy` (200) or `unhealthy` (503). |
| `TomDefaultHealthAnalyzer` | class | Default analyzer. |
| `TomHealthService` | abstract class | Health-check service (`@tomService`). |
| `TomHealthServer` | class | Health-check server component. |
| `TomReadinessCheck` | class | One check of the framework readiness analyzer. |
| `TomFrameworkReadinessAnalyzer` | class | The framework's readiness checks: data sources, migrations, started outboxes. |

### Item Authorization (`lib/src/tomserver/item_authorization/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomItemAuthority` | abstract interface class | The port to the external authority (Tom UAM): checks, accessible items, change feed, sharing. |
| `TomItemAuthorizationClient` | class | Checks and accessible-item lists answered from the cache, the user's sharing acts, the feed follower. |
| `TomItemAuthorityScopeSource` | class | The `resource` row scope fed by the client. |
| `TomItemAuthorizationRecord` | class | One authorization as the authority keeps it. |
| `TomItemShareRequest` | class | A share as a user asks for it. |
| `TomShareSubjectKind` | enum | `user`, `group`. |
| `TomAccessibleItemsPage` | class | One page of the items a principal reaches. |
| `TomSharedItemsPage` | class | One page of the authorizations shared with the user. |
| `TomItemAuthorizationException` | class | A row scope larger than the client may gather (extends `TomServerException`). |

### Little Things (`lib/src/tomserver/little_things/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomServerException` | class | Server-side base exception (extends `TomException`). |
| `TomRequestCache` | abstract final class | Values a request computes once — its row scopes, grants and delegations — emptied by a write (static). |
| `tomErrorEnvelope` | function | Renders any error into the package's wire error body — the shape every error response uses. |
| `tomProblemJsonMediaType` | constant | `application/problem+json`, the media type of an RFC 9457 problem document. |
| `tomProblemJsonContextKey` | constant | `tom.problemJson`, the request context key that answers an endpoint's errors as problem+json. |
| `tomWantsProblemJson` | function | Whether a request is answered with a problem document (context key, or `Accept`). |
| `tomProblemDetails` | function | An error as an RFC 9457 problem document: the envelope plus `type`, `title`, `status`, `instance`. |
| `tomErrorResponse` | function | The error response in the format the request asks for — every framework error response is built here. |
| `tomReasonPhrase` | function | The reason phrase of an HTTP status, a problem document's `title`. |

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
| `TomPushTransport` | class | Real delivery to device tokens through a push service. |
| `TomPushProtocol` | abstract class | One push service's request/response shape, behind an interface. |
| `TomFcmPushProtocol` | class | Firebase Cloud Messaging's HTTP v1 API. |
| `TomApnsPushProtocol` | class | Apple's push service, over HTTP/2. |
| `TomFieldMappedPushProtocol` | class | Any other JSON push API, described by field paths. |
| `TomPushCredential` | abstract class | The bearer token a push service authenticates with. |
| `TomStaticPushCredential` | class | A token the deployment already has. |
| `TomApnsProviderToken` | class | An ES256 APNs provider token, cached for fifty minutes. |
| `TomFcmServiceAccountCredential` | class | An FCM access token minted from a service-account key. |
| `TomPushExchange` | abstract class | The wire, behind an interface so every answer is testable. |
| `TomHttp1PushExchange` | class | HTTP/1.1 over the kernel call layer. |
| `TomHttp2PushExchange` | class | HTTP/2 over `package:http2`, one connection per host. |
| `TomPushSubmission` | class | One notification to one device, as handed to a protocol. |
| `TomPushGatewayRequest` | class | One push call, ready to send. |
| `TomPushGatewayResponse` | class | What the service answered, headers lowercased. |
| `TomPushGatewayAnswer` | class | What a protocol made of it, with a three-valued permanence and a credential flag. |
| `TomPushRequest` | class | A push notification named by a template key, with a data map. |
| `TomPushService` | class | Resolves `.title` and `.body` and queues the notification. |
| `TomWebhookTransport` | class | Real delivery over HTTP: the message's own JSON POSTed to the URL that addresses it. |
| `TomWebhookSettings` | class | The timeout, the always-applied headers, and how much of the answer the receipt keeps. |
| `tomVendorValueAt` | function | The dotted-path reader both vendor mappings share; a numeric segment indexes a list. |
| `TomDeliveryReport` | class | What a carrier says became of a message after accepting it. |
| `TomDeliveryState` | enum | `delivered`, `failed`, `expired`, `unknown` — not the same question as `TomDeliveryOutcome`. |
| `TomDeliveryCorrelation` | class | The `remoteId` → message row: the addresses it went to, and the last state and code reported against it. |
| `TomDeliveryReportStore` | abstract class | The correlation index, addressed by the carrier's id. |
| `TomMemoryDeliveryReportStore` | class | The index in memory; right for a test, wrong across a restart. |
| `TomSqlDeliveryReportStore` | class | The index in a table — the durable half. |
| `TomDeliveryReportRow` | class | One row of that table as the driver hands it back. |
| `deliveryReportTable` | function | The correlation table, declared once. |
| `deliveryReportTableDdl` | function | The `CREATE TABLE` for it, for a deployment that applies DDL by hand. |
| `TomSuppressionList` | abstract class | The addresses a failure report suppresses and no message is sent to. |
| `TomSuppressedAddress` | class | One suppressed address, and the report that added it. |
| `TomMemorySuppressionList` | class | The list in memory; right for a test, wrong across a restart. |
| `TomSqlSuppressionList` | class | The list in a table — the durable half. |
| `TomSuppressionRow` | class | One row of that table as the driver hands it back. |
| `suppressionTable` | function | The suppression table, declared once. |
| `suppressionTableDdl` | function | The `CREATE TABLE` for it, for a deployment that applies DDL by hand. |
| `defaultDeliveryReportTable` | constant | `tom_delivery_report`. |
| `TomDeliveryCallback` | class | What a callback carried, independent of how it arrived. |
| `TomDeliveryReportProtocol` | abstract class | The carrier's callback shape, behind an interface. |
| `TomFieldMappedDeliveryReportProtocol` | class | That shape described by field names and status tokens; no vendor presets. |
| `TomDeliveryCallbackRequest` | class | A carrier callback as a verifier sees it: method, URL, lowercased headers, the body read once, query and form parameters. |
| `TomDeliveryCallbackVerifier` | abstract class | What gates the callback route: whether a request comes from the carrier. |
| `TomSharedSecretCallbackVerifier` | class | A shared secret the carrier presents in a header (`x-tom-delivery-secret` by default). |
| `TomTwilioCallbackVerifier` | class | Twilio's `X-Twilio-Signature` (HMAC-SHA1 over the URL and the sorted POST parameters); `publicUrl` for a proxy. |
| `TomVonageSignatureMethod` | enum | `md5hash`, `md5`, `sha1`, `sha256`, `sha512` — how a Vonage account signs. |
| `TomVonageCallbackVerifier` | class | Vonage's `sig` parameter, with a `maxAge` replay window on its `timestamp`. |
| `tomConstantTimeEquals` | function | String equality in time that depends only on the lengths. |
| `TomDeliveryReportEndpoint` | class | The static configuration behind the callback route, and its handler; `install` takes the store, the protocol and the verifier. |
| `TomDeliveryReportService` | abstract class | The reflected `POST`/`GET /messaging/delivery-report` declaration. |
| `TomDeliveryReportServer` | class | Its default implementation. |
| `TomInboxException` | class | An empty or over-long consumer name or message id (extends `TomServerException`). |
| `TomInboxOutcome` | enum | `processed`, `duplicate`. |
| `TomInbox` | abstract class | The idempotent receiver: record and work in one transaction, acknowledge after the commit, skip a message already processed. |
| `TomMemoryInbox` | class | The inbox in memory; for tests, forgotten on restart. |
| `TomSqlInbox` | class | The inbox in a table of the data source the consumer's work writes to. |
| `TomInboxRow` | class | One row of that table as the driver hands it back. |
| `inboxTable` | function | The inbox table, declared once. |
| `inboxTableDdl` | function | The `CREATE TABLE` for it, for a deployment that applies DDL by hand. |
| `defaultInboxTable` | constant | `tom_message_inbox`. |
| `TomSmsSubmission` | class | One recipient's share of a message, as handed to a protocol. |
| `TomSmsSegmentation` | class | What a text costs: encoding, units, segments. |
| `TomSmsEncoding` | enum | `gsm7`, `ucs2`. |
| `TomMimeEncoder` | class | Renders a message as an RFC 5322 / MIME document. |
| `TomMessageOutbox` | class | The durable send queue in front of a router. |
| `TomBusRelay` | class | The transactional outbox for a `TomMessageBus`: queued in the caller's transaction, published after the commit. |
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
| `tomBusRelayJobName` | top-level | The default job name the bus relay registers under. |
| `tomSuppressedDetail` | function | Why a [TomMessageRouter] sent nothing: every recipient was suppressed. |

### Metrics (`lib/src/tomserver/metrics/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomOtlpExportException` | class | An OTLP export not delivered, or headers that cannot be read (extends `TomServerException`). |
| `TomOtlpHttpTransport` | class | Posts OTLP/HTTP JSON bodies to `<endpoint>/v1/<signal>`; signal-neutral. |
| `TomOtlpMetricsExporter` | class | Pushes the registry to an OTLP receiver every interval, cumulatively, and once more on close. |
| `tomRequestMetricsMiddleware` | function | Records the request series by method, route pattern and status. |
| `tomMetricsEndpointMiddleware` | function | Answers a Prometheus scrape ahead of authentication, with an optional bearer token. |
| `tomOtlpMetricsJson` | function | A snapshot as an OTLP `ExportMetricsServiceRequest` in JSON. |
| `tomUnmatchedRoute` | constant | `unmatched` — the route label of a request no endpoint matched. |

### Notifications (`lib/src/tomserver/notifications/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomNotificationException` | class | A notification that cannot be declared, raised or rendered (extends `TomServerException`). |
| `TomNotificationType` | class | A kind of notification the application raises, and its policy: allowed and default channels, category, mandatory, urgent. |
| `TomNotificationRecipient` | class | A principal a notification reaches, with the addresses they can be reached at per channel. |
| `TomNotification` | class | One occurrence: type, parameters, named recipients, and the id every message it fans out to derives its id from. |
| `TomNotificationAudience` | abstract class | Subscription resolution: who receives a notification of one type; `.of(function)` for a function. |
| `TomNotificationCatalog` | class | The registered types, each with its audience; installed as a bean. |
| `TomQuietHours` | class | A daily window, `HH:MM-HH:MM` in the principal's zone, during which non-urgent notifications are held. |
| `TomNotificationChoiceOrigin` | enum | Where a recipient's channels came from: `type`, `category` or `defaults`. |
| `TomNotificationChoice` | class | What a principal receives one type on, with their quiet hours and zone. |
| `TomNotificationPreferenceSource` | abstract class | Reads a principal's stored notification preference values. |
| `TomUserPreferencesNotificationSource` | class | That source over `TomUserPreferences`, role and deployment defaults included. |
| `TomNotificationPreferences` | class | The choice rules (type key, category key, type defaults, within the allowed channels), and the writes of the caller's choices. |
| `TomNotificationRendering` | class | One notification, for one recipient, on one channel, under one message id. |
| `TomNotificationRenderer` | abstract class | Turns a rendering into a `TomMessage`. |
| `TomTemplatedNotificationRenderer` | class | Renders from the `notification.<type>[.<channel>]` resource keys `subject`, `body` and `html`; a webhook gets the notification as JSON. |
| `TomNotificationDeliveryOutcome` | enum | `queued`, `deferred`, `digested`, `alreadyQueued` or `noAddress`. |
| `TomNotificationDelivery` | class | One recipient-channel pair of a dispatch and what became of it. |
| `TomNotificationDispatchReport` | class | Every pair a dispatch considered, and the recipients who opted out. |
| `TomNotificationDispatcher` | class | Fans a notification out to the messaging outbox, once per recipient and chosen channel, with deterministic message ids. |
| `TomNotificationCadence` | enum | How often a recipient receives a type: `immediate`, `hourly` or `daily`. |
| `TomNotificationDigestItem` | class | One notification collected into a digest, as its payload holds it. |
| `TomNotificationDigestRendering` | class | One digest — the items collected for one recipient on one channel — to render as one message. |
| `TomNotificationDigests` | class | Collects hourly and daily notifications as pending job runs and sends each digest through the outbox when it is due. |
| `tomNotificationDigestJobName` | constant | `notifications.digest` — the job name digest runs are stored under. |
| `TomNotificationPreferencesServer` | class | The `@TomApiImplementation` behind the kernel's `tomNotificationPreferencesApi` (`GET /notification-preferences`). |

### Object Persistence (`lib/src/tomserver/object_persistence/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomDbTable` / `TomDbColumn` / `TomEntityId` / `TomDbScope` / `TomReference` | class | Persistence annotations. |
| `TomVersion` | class | Marks the `int` field holding a row's version, turning on optimistic locking for the entity. |
| `TomTenantOwned` | class | Marks an entity whose every row belongs to a tenant; the repository reads and writes only the current tenant's rows. |
| `TomDartType` | class | Dart-type descriptor for persistence. |
| `TomColumnInformation` | class | Column metadata. |
| `TomRepository<T, K>` | abstract class | Repository contract. |
| `TomSqlDatasourceRepository<T, K>` | abstract class | SQL-datasource repository base; `upsert` / `saveByKey` write by a unique business key in one statement. |
| `MariadbRepository<T, K>` | class | MariaDB repository. |
| `TomCompositeKey` | final class | The key value of an entity whose primary key spans several fields. |
| `TomCountResult` | class | Count query result. |
| `TomQueryBuilder` | mixin | Fluent query building. |
| `TomQuerySentenceCompiler` | class | Compiles query sentences to SQL, including terms on an association as a correlated `EXISTS`. |
| `TomSubquery` | class | A subquery over entity types, with an optional predicate and projection. |
| `TomExists` / `TomInSubquery<T>` | class | `EXISTS (<subquery>)` and `<operand> IN (<subquery>)`. |
| `TomOperator` / `TomUnaryOperator` / `TomBinaryOperator` / `Parameter` | abstract class | The expression tree: a node, its one- and two-operand bases, and a bound parameter. The concrete nodes are `DbCol`/`IntCol`/`StringCol`/`DoubleCol`/`BoolCol`/`DateTimeCol`/`DateCol`/`TimeCol`, the `*Literal` set, the constant predicate `TruthPredicate`, and `And`/`Or`/`Not`/`Eq`/`Neq`/`Lt`/`Gt`/`Lte`/`Gte`/`Like`/`NotLike`/`In`/`Group`/`Between`/`Regexp`/`IsNull`/`IsNotNull`. |
| `TomAggregate<R, V>` | abstract class | An aggregate function applied to a group: `COUNT(*)`, `SUM(t.amount)`, `MAX(t.created)`. |
| `CountAll` / `Count<T>` / `Sum<T>` / `Avg<T>` / `Min<R, V>` / `Max<R, V>` | class | The concrete aggregate nodes. |
| `TomGroupedSelect` | class | A `SELECT … GROUP BY …` over the entity types, with `WHERE` and `HAVING`. |
| `TomGroupedRow` | class | One row of a grouped result: group keys plus aggregates, each under its projected alias. |
| `TomPageRequest` | class | One window of a result set: `offset` rows in, at most `limit` wide, ordered by `sort`. |
| `TomSortField` | class | One term of a sort: a field and the direction it orders in. |
| `TomSortDirection` | enum | `ascending` / `descending`, rendering `ASC` / `DESC`. |
| `TomQuerySyntaxException` | class | Query syntax error. |
| `TomRepositoryException` | class | A repository precondition fails — unregistered datasource, a key lookup matching more than one row, a row that could not be read back. |
| `TomOptimisticLockException` | class | A save or delete of a versioned entity refused because the row's version moved since it was loaded (extends `TomRepositoryException`). |
| `TomResourceScopeSource` | abstract class | The grant-driven source behind the built-in `resource` scope kind. |
| `TomFileReference` | class | Annotation marking a `String` column as holding a blob storage key rather than the bytes. |
| `TomFileReferenceKeys` | class | Resolves the store and mints the keys for a `@TomFileReference` column (static). |
| `TomBlobMigration` | class | Moves the blobs a repository's rows name from one blob store to another. |
| `TomBlobMigrationReport` | class | What one blob migration did. |
| `TomBlobMigrationException` | class | A blob migration cannot proceed, or cannot be trusted. |
| `TomFileRepository<T, K>` | abstract class | The subset of a repository the file surfaces need: load a row, move one column's bytes. |
| `TomBlobOrphanSweep` | class | Deletes the keys of a deduplicating blob store no row refers to, then reclaims their content. |
| `TomBlobOrphanSweepReport` | class | What one orphan sweep did. |
| `TomBlobReferenceSource` | abstract class | Something that knows which blob keys its rows refer to. |
| `TomRepositoryBlobReferences<T, K>` | class | A repository's file columns as a reference source. |
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
| `TomEncrypted` | class | Marks a `String` field encrypted at rest. |
| `TomBlindIndex` | class | Makes a `String` column the blind index of an encrypted field. |
| `TomBlindIndexNormalization` | enum | `exact`, `trim` or `trimLowercase` — how a blind index normalises a value. |
| `TomFieldEncryption` | abstract final class | The installed keyring, the cipher, blind-index lookups, raw reads and audit redaction (static). |
| `TomFieldKeyring` | class | The data keys, unwrapped and cached; rotates data keys, index keys and key-encryption keys. |
| `TomKeyEncryptionKey` | abstract class | What wraps the data keys. |
| `TomAesKeyEncryptionKey` | class | An application-held AES-256 key-encryption key. |
| `TomKeyEncryptionKeyFactory` | typedef | Builds the key-encryption key of a `fieldEncryption.keys` entry of a registered kind (`TomFieldEncryption.registerKeyKind`). |
| `TomAesGcm` | abstract final class | AES-256-GCM with a random nonce: the cipher of field encryption, data-key wrapping and the sealing of audit values (static). |
| `TomDataKeyStore` | abstract class | Where the wrapped data keys are kept. |
| `TomSqlDataKeyStore` / `TomMemoryDataKeyStore` | class | The data keys in `tom_encryption_key` of a data source resolved by name per call / in memory. |
| `TomDataKeyRecord` | class | One data key as stored, wrapped. |
| `TomDataKeyRow` | class | One row of the data-key table. |
| `TomDataKeyPurpose` / `TomDataKeyState` | enum | `encryption` or `blindIndex`; `active` or `previous`. |
| `TomFieldReencryption` | class | The pass, and its scheduler job, rewriting values under a previous key, plaintext and stale blind indexes. |
| `TomReencryptionReport` | class | What one re-encryption pass did. |
| `TomFieldEncryptionException` | class | Field encryption that cannot proceed, keyed `field_encryption.*` (extends `TomServerException`). |
| `encryptionKeyTable` / `encryptionKeyTableDdl` | top-level | The data-key table's descriptor, and its `CREATE TABLE` statement. |
| `defaultEncryptionKeyTable` | top-level | `tom_encryption_key`, the data-key table's default name. |
| `tomReencryptionJobName` | top-level | `object_persistence.reencrypt`, the re-encryption job's default name. |
| `TomSoftDelete` | class | Marks an entity whose repository deletes set a deletion time and whose deleted rows repository reads leave out; `includingDeleted` shows them. |
| `TomHistory` | class | Marks an entity whose rows are copied into a history table before every update, delete and restore. |
| `TomHistoryEntry<T>` | class | One past version of a row, as `historyOf` answers it. |
| `TomHistoryMeta` | class | The history table's own four columns, read by reflection. |
| `TomEntityListener<T>` | abstract class | The `beforeSave` / `afterSave` / `beforeDelete` / `afterDelete` hooks of one entity type's repository writes. |
| `TomEntityChange` | class | One change of one row, with the row before and after and `toJson()`. |
| `TomEntityChangeKind` | enum | `inserted`, `updated`, `deleted` or `restored`. |
| `TomEntityChangeListener` | typedef | Told of every change of its entity inside the change's transaction. |
| `TomEntityLifecycle` | abstract final class | The registry of entity listeners and change listeners (static). |
| `TomEntityLifecycleException` | class | A lifecycle declaration that cannot be carried out, or a soft-delete or history method on an entity without one (extends `TomServerException`). |

### Preferences (`lib/src/tomserver/preferences/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomUserPreference` | class | The `tom_user_preference` row; `@TomDbScope(field: 'principal_id', scope: 'owner')` is the whole ownership rule. |
| `TomUserPreferenceRepository` | class | The CRUD repository for that entity. |
| `TomUserPreferences` | class | Typed `get`/`set`/`getOr`/`read`/`all`/`remove`/`clear` for the caller in the request zone, `setAllEncoded` for the all-or-none bulk write, plus `getFor` for the login path; reads and lists include the defaults beneath the caller's own values. Installed as a bean. |
| `TomUserPreferenceException` | class | An operation that cannot identify the caller, or a write past the principal's ceiling (extends `TomServerException`). |
| `TomPreferenceDefaultScope` | enum | `deployment` or `role` — whom a default applies to. |
| `TomPreferenceDefault` | class | The `tom_preference_default` row: one default for the deployment or for one role, with a `precedence` between roles. |
| `TomPreferenceDefaultRepository` | class | The CRUD repository for that entity. |
| `TomPreferenceDefaults` | class | Writes deployment and role defaults (administrative, no endpoint) and chooses the one a principal reads. Installed as a bean. |
| `TomUserPreferencesServer` | class | The `@TomApiImplementation` behind the kernel's `tomUserPreferencesApi`. |
| `TomUserPreferencesErrorHandler` | class | Maps `preferences.not_found` to a `404`, `preferences.key.invalid`, `preferences.encoded.*` and `preferences.bulk.malformed` to a `400`, and `preferences.limit.exceeded` to a `409`, so a client can tell a miss or its own mistake from an outage. |

### Privacy (`lib/src/tomserver/privacy/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomDataSubject` | class | Marks the field holding the id of the person a row belongs to or names, and what erasing them does to the row. |
| `TomErasure` | enum | `delete`, `anonymize` or `unlink`. |
| `TomPersonal` | class | Marks a field holding personal data about a subject field's subject: exported, cleared on erasure, sealed in the audit trail. |
| `TomRetention` | class | How long an entity's rows are kept, and whether they are then deleted or anonymized. |
| `TomPersonalDataModel` | class | An entity's declarations, resolved and checked. |
| `TomSubjectField` / `TomPersonalField` | class | One resolved subject field / personal field. |
| `TomPrivacy` | abstract final class | Registration, erasure, subject-access export, retention, the subject keys and revealing an audit record (static). |
| `TomErasureReport` / `TomErasureCount` | class | What an erasure did, in all / to one entity. |
| `TomSubjectAccess` | class | A subject-access export: one tabular section per entity. |
| `TomRetentionPolicy` / `TomRetentionCount` | class | One retention rule / what it did in a run. |
| `TomSubjectKeys` | class | Seals personal values under a key per subject, opens them, shreds the key. |
| `TomSubjectKeyStore` | abstract class | Where the wrapped subject keys are kept. |
| `TomSqlSubjectKeyStore` / `TomMemorySubjectKeyStore` | class | The subject keys in `tom_subject_key` of a data source resolved by name per call / in memory. |
| `TomSubjectKeyRecord` / `TomSubjectKeyRow` | class | One subject key as stored / one row of its table. |
| `TomPrivacyException` | class | A declaration or operation that cannot proceed, keyed `privacy.*` (extends `TomServerException`). |
| `subjectKeyTable` / `subjectKeyTableDdl` | top-level | The subject-key table's descriptor, and its `CREATE TABLE` statement. |
| `defaultSubjectKeyTable` | top-level | `tom_subject_key`, the subject-key table's default name. |
| `tomRetentionJobName` | top-level | `privacy.retention`, the retention job's default name. |

### Rate Limiting (`lib/src/tomserver/ratelimit/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomRateLimits` | class | The rules, the limiter and the trusted proxies; installed once per process or from the `rateLimits` configuration key. |
| `TomRateLimitRule` | class | At most `limit` requests per `window` per key of a scope, optionally on some paths. |
| `TomRateLimitScope` | enum | `principal`, `apiKey` or `address`. |
| `TomRateLimitDecision` | class | One counted request's outcome; `slidingWindow` is the shared arithmetic. |
| `TomRateLimiter` | abstract class | Counts one request for a key under a rule. |
| `TomMemoryRateLimiter` | class | Sliding-window counters in this process — per node. |
| `TomSqlRateLimiter` | class | Sliding-window counters in `tom_rate_limit`, shared by every node. |
| `TomRateLimitRow` | class | One counter row, as the shared limiter reads it back. |
| `TomClientAddress` | abstract final class | The socket peer, or `X-Forwarded-For` behind a trusted proxy. |
| `TomRateLimitException` | class | `rate_limit.exceeded` and the configuration refusals (extends `TomServerException`). |
| `tomRateLimitMiddleware` | function | The middleware `TomServer` installs inside authentication. |
| `rateLimitTable` | top-level function | The `tom_rate_limit` declaration. |
| `defaultRateLimitTable` | constant | `tom_rate_limit`. |
| `tomRateLimitRefusalsMetric` | constant | `tom_rate_limit_refusals` — the counter of refused requests by `rule` and `tenant`. |
| `tomNoTenantLabel` | constant | `none` — the `tenant` label outside any tenant. |

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
| `TomJobPauseRow` | class | One row of the paused-job table. |
| `TomJobRunArchiveRow` | class | One row of the run archive. |
| `TomArchivedJobRun` | class | A run read back from the archive, with when it was archived. |
| `TomJobRunWindowRow` | class | The aggregate column `lastWindow` projects. |
| `TomJobBacklogRow` | class | One job's aggregate row of `backlog`: due runs and the earliest `run_at`. |
| `TomSqlLeaseLock` | class | A `TomLeaseLock` whose leases are rows in a `TomDataSource`. |
| `TomLeaseRow` | class | One row of the lease table. |
| `TomSqlSchedulerNodes` | class | The cluster roll call, backed by a table. |
| `TomSchedulerNode` | class | One node of the cluster, as the roll call knows it. |
| `TomSchedulerNodeRow` | class | One row of the roll-call table. |
| `schedulerNodeFailedAfter` / `isSchedulerNodeFailed` | top-level | When a peer counts as failed, and whether it does. |
| `defaultNodeFailureSlack` | top-level | The grace period added to a peer's expected check-in. |
| `defaultJobRunTable` / `defaultJobPauseTable` / `defaultJobRunArchiveTable` / `defaultLeaseTable` / `defaultSchedulerNodeTable` | top-level | Default table names. |
| `jobRunTable` / `jobPauseTable` / `jobRunArchiveTable` / `leaseTable` / `schedulerNodeTable` | top-level | The table descriptors. |
| `jobRunTableDdl` / `jobPauseTableDdl` / `jobRunArchiveTableDdl` / `leaseTableDdl` / `schedulerNodeTableDdl` | top-level | The `CREATE TABLE` statements. |

### Server (`lib/src/tomserver/server/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomServer` | class | The HTTP server. |
| `TomRequestLogInfo` | class | Per-request log record; carries the matched endpoint's `route` pattern the request metrics read. |
| `TomCredentialOutcome` | enum | Why a request carries the credentials it does. |
| `TomEndpointCredentials` | abstract final class | The path prefixes whose `Authorization` header belongs to the endpoint; `extractAuthentication` leaves it unread. |
| `contextSetupMiddleware` | function | Seeds the same entries into every request's context. |
| `extractAuthentication` | function | Extracts principal + JWT from a request. |
| `tomDefaultAuthenticationMiddleware` | function | Default auth middleware. |
| `tomLoggingMiddleware` | function | Request-logging middleware. |
| `tomRequestLogInfoMiddleware` | function | Seeds a new `TomRequestLogInfo` into every request's context. |
| `tomRequestIdHeader` | constant | `X-Request-Id`, the default request-id header: echoed on every response, believed from a trusted proxy. |
| `tomRequestContextMiddleware` | function | Continues or starts the W3C trace, runs the request under the id its `TomRequestIdPolicy` chooses, answers with both. |
| `TomRequestIdPolicy` | final class | Which request id a request runs under: a trusted proxy's request-id header, else the trace id; set from the `requestIds` key. |
| `TomRequestIdException` | class | The `requestIds` settings cannot be applied (extends `TomServerException`). |
| `TomSecurityHeaders` | final class | The security headers every response carries unless it sets its own — HSTS on HTTPS, a deny-all CSP, `nosniff`, `X-Frame-Options`, `Referrer-Policy`; set from the `securityHeaders` key. |
| `TomContentSecurityPolicyHook` | typedef | Chooses the `Content-Security-Policy` of one response; `null` falls back to the configured one. |
| `TomSecurityHeadersException` | class | The `securityHeaders` settings cannot be applied (extends `TomServerException`). |
| `tomSecurityHeadersMiddleware` | function | Adds `TomSecurityHeaders.current`'s headers to every response, error responses included. |
| `TomMutualTls` | final class | Mutual TLS: the client CA, the certificates that name service principals, and the paths only services may call; set from the `mutualTls` key. |
| `TomTlsConnectionInfo` | class | The connection of a TLS request, with the client certificate it presented. |
| `TomMutualTlsClientFactory` | class | The outgoing framework client presenting this service's certificate. |
| `TomMutualTlsException` | class | The `mutualTls` settings cannot be applied, or a path that requires a client certificate was reached without one (extends `TomServerException`). |
| `noopHandler` | function | A handler returning a fixed status. |
| `TomGracefulShutdown` | class | What the server does between SIGTERM and exiting: readiness off, new requests refused, work in flight finished, leases released, pools closed. |
| `tomProbePaths` | constant | `health` and `ready`, the paths a draining server keeps answering. |

### Sync (`lib/src/tomserver/sync/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomSync` | abstract final class | The exposed collections, `expose`, `push` and `pull` (static). |
| `TomSqlSyncLog` | class | The change log in each synced entity's data source: `prepare`, `append`, `number`, `after`. |
| `TomSyncChangeRow` / `TomSyncChangeIdRow` / `TomSyncSequenceRow` | class | One change-log row / an unnumbered change's id / a counter's value, as the log reads them. |
| `TomSyncServer` | class | `POST /sync/push` and `POST /sync/pull`, the kernel's `TomSyncApiService`. |
| `TomSyncErrorHandler` | class | Maps a pull's refusals to `400`. |
| `TomSyncException` | class | The module's failures, keyed `sync.*` (extends `TomServerException`). |
| `TomSyncRejection` | class | Thrown by the application to refuse a pushed change with a reason (extends `TomSyncException`). |
| `syncChangeTable` / `syncSequenceTable` | top-level function | The two tables' declarations. |
| `defaultSyncChangeTable` / `defaultSyncSequenceTable` | constant | `tom_sync_change` / `tom_sync_sequence`. |

### Tenancy (`lib/src/tomserver/tenancy/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomTenancy` | class | The deployment's tenants, their routing and request resolution; installed once per process. |
| `TomTenant` | class | One tenant: its id, name, isolation model, schema and data sources. |
| `TomTenantIsolation` | enum | `shared`, `schema` or `database` — where a tenant's rows live. |
| `TomTenancyException` | class | Tenancy configuration or unknown-tenant error (extends `TomServerException`). |
| `TomTenantResolver` | abstract interface class | Reads a tenant id from a request without a token claim. |
| `TomTenantHostResolver` | class | Names the tenant by an exact host or a subdomain. |
| `TomTenantPathResolver` | class | Names the tenant by the path segment after a prefix, `/t/<segment>` by default. |
| `TomTenantHeaderResolver` | class | Names the tenant by a header, `X-Tenant-Id` by default. |
| `TomTenantResolution` | class | A request's tenant, none, or the rejection to answer it with. |

### Tracing (`lib/src/tomserver/tracing/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomTracingException` | class | Tracing cannot be set up as configured (extends `TomServerException`). |
| `TomOtelTracer` | class | The kernel's `TomTracer` over the OpenTelemetry SDK, exporting spans over OTLP/HTTP; installed by `TomServer.start` when `tracing` is on. |
| `TomUntracedClient` | class | An HTTP client whose calls are never traced, and whose close lets calls in flight finish — what the span exporter sends through. |
| `TomInMemorySpanExporter` | class | A span exporter keeping exported spans in memory; for tests. |

### Transactions (`lib/src/tomserver/transactions/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomTransactionManager` | abstract class | Transaction coordination (static, zone-scoped per flow). |
| `TomTransaction` | class | An in-flight transaction. |
| `TomTransactionParticipant` | abstract class | Participant contract (2-phase commit). |
| `TomTransactionResult` | class | What a conclusion did, and to whom. |
| `TomTransactionOutcome` | enum | Committed, partially committed, rolled back, rolled back with failures. |
| `TomTransactionException` | class | Transaction error. |
| `TomPreparedBranchHolder` | abstract interface class | A participant holding a two-phase branch, whose id the coordinator records. |
| `TomTransactionDecisionLog` | abstract interface class | The coordinator's durable record of commit decisions. |
| `TomMemoryDecisionLog` | class | Decisions in memory; for tests. |
| `TomSqlDecisionLog` | class | Decisions in `tom_transaction_decision` of a one-phase SQL data source. |
| `TomDecisionRow` | class | One row of the decision table. |
| `TomTwoPhaseRecoverable` | abstract interface class | A data source whose prepared branches a recovery lists and resolves. |
| `TomTransactionRecovery` | abstract final class | Commits the prepared branches a recorded decision names, rolls back the rest; the `transactions` configuration. |
| `TomRecoveryReport` | class | What one recovery did. |
| `TomTransactionRecoveryException` | class | Transaction recovery misconfigured (extends `TomServerException`). |
| `defaultDecisionTable` | top-level | `tom_transaction_decision`, the decision table's default name. |
| `decisionTable` / `decisionTableDdl` | top-level | The decision table's descriptor, and its `CREATE TABLE` statement. |
| `TomSagaException` | class | A saga that cannot be declared, begun or stored (extends `TomServerException`). |
| `TomSagaWork` | typedef | The work of a step or a compensation. |
| `TomSagaStep` | class | One step of a saga: an action and, optionally, the compensation that undoes it. |
| `TomSaga` | class | The declaration of a saga: its steps, in order, and how they are retried. |
| `TomSagaContext` | class | What a step's action or compensation is given. |
| `TomSagaStatus` | enum | Running, compensating, completed, compensated, failed. |
| `TomSagaState` | class | The persisted progress of one saga. |
| `TomSagaStore` | abstract class | Where saga states are kept, in the tenant in context. |
| `TomMemorySagaStore` | class | Saga states in memory; for tests. |
| `TomSqlSagaStore` | class | Saga states in `tom_saga` of a SQL data source, resolved by name per call. |
| `TomSagaRow` | class | One row of the saga table. |
| `tomSagaJobPrefix` | top-level | `saga`, the default prefix of the orchestrator's job names. |
| `TomSagaOrchestrator` | class | Runs sagas: each step and compensation a job run of its own inline scheduler, in a local transaction guarded by the saga's version. |
| `defaultSagaTable` | top-level | `tom_saga`, the saga table's default name. |
| `sagaTable` / `sagaTableDdl` | top-level | The saga table's descriptor, and its `CREATE TABLE` statement. |

## Alphabetical Type Index

| Type | Module |
| ---- | ------ |
| `And` | Object Persistence |
| `apiKeyTable` | Authentication |
| `applyExternalRoles` | Authentication |
| `auditDiff` | Audit |
| `auditProjectionPrefix` | Audit |
| `auditTrailGuardStatements` | Audit |
| `auditTrailNoDeleteTriggerDdl` | Audit |
| `auditTrailNoDeleteTriggerName` | Audit |
| `auditTrailNoUpdateTriggerDdl` | Audit |
| `auditTrailNoUpdateTriggerName` | Audit |
| `auditTrailTable` | Audit |
| `auditTrailTableDdl` | Audit |
| `Avg` | Object Persistence |
| `Between` | Object Persistence |
| `blobChunkTable` | File Storage |
| `blobChunkTableDdl` | File Storage |
| `blobContentTable` | File Storage |
| `blobContentTableDdl` | File Storage |
| `blobLedgerTable` | File Storage |
| `blobLedgerTableDdl` | File Storage |
| `blobManifestTable` | File Storage |
| `blobManifestTableDdl` | File Storage |
| `BoolCol` | Object Persistence |
| `BoolLiteral` | Object Persistence |
| `classifySqlFailure` | Datasources |
| `contextSetupMiddleware` | Server |
| `Count` | Object Persistence |
| `CountAll` | Object Persistence |
| `DateCol` | Object Persistence |
| `DateLiteral` | Object Persistence |
| `DateTimeCol` | Object Persistence |
| `DateTimeLiteral` | Object Persistence |
| `DbCol` | Object Persistence |
| `decisionTable` | Transactions |
| `decisionTableDdl` | Transactions |
| `defaultApiKeyTable` | Authentication |
| `defaultAuditTrailTable` | Audit |
| `defaultBlobChunkTable` | File Storage |
| `defaultBlobContentTable` | File Storage |
| `defaultBlobLedgerTable` | File Storage |
| `defaultBlobManifestTable` | File Storage |
| `defaultDecisionTable` | Transactions |
| `defaultDeliveryReportTable` | Messaging |
| `defaultEncryptionKeyTable` | Object Persistence |
| `defaultExportRegisterTable` | Export |
| `defaultIdempotencyTable` | Endpoints |
| `defaultInboxTable` | Messaging |
| `defaultInvalidationTable` | Cache |
| `defaultJobPauseTable` | Scheduling |
| `defaultJobRunArchiveTable` | Scheduling |
| `defaultJobRunTable` | Scheduling |
| `defaultLeaseTable` | Scheduling |
| `defaultNodeFailureSlack` | Scheduling |
| `defaultOAuthStateTable` | Authentication |
| `defaultRateLimitTable` | Rate Limiting |
| `defaultSagaTable` | Transactions |
| `defaultSchedulerNodeTable` | Scheduling |
| `defaultScimResourceTable` | Authentication |
| `defaultServiceAccountTable` | Authentication |
| `defaultSubjectKeyTable` | Privacy |
| `defaultSyncChangeTable` | Sync |
| `defaultSyncSequenceTable` | Sync |
| `deliveryReportTable` | Messaging |
| `deliveryReportTableDdl` | Messaging |
| `DoubleCol` | Object Persistence |
| `DoubleLiteral` | Object Persistence |
| `encryptionKeyTable` | Object Persistence |
| `encryptionKeyTableDdl` | Object Persistence |
| `Eq` | Object Persistence |
| `exportRegisterTable` | Export |
| `exportRegisterTableDdl` | Export |
| `extractAuthentication` | Server |
| `filterAuditEntries` | Audit |
| `frameworkOwnedTables` | Database Migration |
| `Group` | Object Persistence |
| `Gt` | Object Persistence |
| `Gte` | Object Persistence |
| `idempotencyTable` | Endpoints |
| `idempotencyTableDdl` | Endpoints |
| `In` | Object Persistence |
| `inboxTable` | Messaging |
| `inboxTableDdl` | Messaging |
| `InMemoryPrincipalDelegationStore` | Authorization |
| `InMemoryPrincipalResourceGrantStore` | Authorization |
| `installJwtSigning` | Authentication |
| `IntCol` | Object Persistence |
| `IntegerLiteral` | Object Persistence |
| `invalidationTable` | Cache |
| `invalidationTableDdl` | Cache |
| `isDevelopmentOrTestRuntime` | Configuration |
| `isLostConnectionFailure` | Datasources |
| `IsNotNull` | Object Persistence |
| `IsNull` | Object Persistence |
| `isSchedulerNodeFailed` | Scheduling |
| `jobPauseTable` | Scheduling |
| `jobPauseTableDdl` | Scheduling |
| `jobRunArchiveTable` | Scheduling |
| `jobRunArchiveTableDdl` | Scheduling |
| `jobRunTable` | Scheduling |
| `jobRunTableDdl` | Scheduling |
| `leaseTable` | Scheduling |
| `leaseTableDdl` | Scheduling |
| `Like` | Object Persistence |
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
| `Max` | Object Persistence |
| `Min` | Object Persistence |
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
| `parseSqlDate` | Datasources |
| `parseSqlInstant` | Datasources |
| `parseSqlTimeOfDay` | Datasources |
| `PostgresConnectionLostException` | Datasources |
| `PostgresDatasource` | Datasources |
| `PostgresDatasourceException` | Datasources |
| `PostgresMigrationAdaptor` | Database Migration |
| `PostgresMigrationException` | Database Migration |
| `PostgresSqlDialect` | Datasources |
| `PostgresXADatasource` | Datasources |
| `PrincipalDelegationStore` | Authorization |
| `PrincipalResourceGrantStore` | Authorization |
| `rateLimitTable` | Rate Limiting |
| `readPemFile` | Authentication |
| `Regexp` | Object Persistence |
| `RepositoryPrincipalDelegationStore` | Authorization |
| `RepositoryPrincipalResourceGrantStore` | Authorization |
| `sagaTable` | Transactions |
| `sagaTableDdl` | Transactions |
| `schedulerNodeFailedAfter` | Scheduling |
| `schedulerNodeTable` | Scheduling |
| `schedulerNodeTableDdl` | Scheduling |
| `scimKeyOf` | Authentication |
| `scimLookup` | Authentication |
| `scimResourceTable` | Authentication |
| `scimResourceTableDdl` | Authentication |
| `scimValues` | Authentication |
| `selectedRuntimeEnvironmentName` | Configuration |
| `serviceAccountTable` | Authentication |
| `sqlDate` | Datasources |
| `sqlFailureCauses` | Datasources |
| `sqlInstant` | Datasources |
| `SqlPlaceholderScan` | Datasources |
| `SqlString` | Datasources |
| `sqlTimeOfDay` | Datasources |
| `StringCol` | Object Persistence |
| `StringLiteral` | Object Persistence |
| `subjectKeyTable` | Privacy |
| `subjectKeyTableDdl` | Privacy |
| `Sum` | Object Persistence |
| `syncChangeTable` | Sync |
| `syncSequenceTable` | Sync |
| `TimeCol` | Object Persistence |
| `TimeLiteral` | Object Persistence |
| `Tom2FAAdaptor` | Authentication |
| `Tom2FAAttempt` | Authentication |
| `Tom2FAAttemptStore` | Authentication |
| `Tom2FAChallengeSpec` | Authentication |
| `Tom2FAContext` | Authentication |
| `Tom2FADecision` | Authentication |
| `Tom2FAEnrolment` | Authentication |
| `Tom2FAEnrolmentOffer` | Authentication |
| `Tom2FAEnrolmentState` | Authentication |
| `Tom2FAEnrolmentStore` | Authentication |
| `Tom2FAEnrolmentSupport` | Authentication |
| `Tom2FAException` | Authentication |
| `Tom2FAGraceAccounting` | Authentication |
| `Tom2FAGraceStore` | Authentication |
| `Tom2FAMemoryAttemptStore` | Authentication |
| `Tom2FAMemorySendLimiter` | Authentication |
| `Tom2FAPolicy` | Authentication |
| `Tom2FAPrerequisite` | Authentication |
| `Tom2FARegistry` | Authentication |
| `Tom2FARequirement` | Authentication |
| `Tom2FASend` | Authentication |
| `Tom2FASendLimiter` | Authentication |
| `Tom2FAService` | Authentication |
| `Tom2FASubmission` | Authentication |
| `tom2FATokenFingerprint` | Authentication |
| `TomAccessibleItemsPage` | Item Authorization |
| `TomAesGcm` | Object Persistence |
| `TomAesKeyEncryptionKey` | Object Persistence |
| `TomAggregate` | Object Persistence |
| `TomAggregateFunction` | Datasources |
| `TomAnnotationAnalyzer` | Object Persistence |
| `TomAnnotationAnalyzerException` | Object Persistence |
| `TomAnnotationAnalyzerSyntaxException` | Object Persistence |
| `TomApiEndpointImplementation` | Endpoints |
| `TomApiImplementation` | Endpoints |
| `TomApiKey` | Authentication |
| `TomApiKeyException` | Authentication |
| `TomApiKeyIdentity` | Authentication |
| `TomApiKeyRow` | Authentication |
| `TomApiKeys` | Authentication |
| `TomApiKeyStore` | Authentication |
| `TomApnsProviderToken` | Messaging |
| `TomApnsPushProtocol` | Messaging |
| `tomAppId` | Configuration |
| `TomArchivedJobRun` | Scheduling |
| `TomArgs` | Command Line |
| `TomAsyncDataScopeResolver` | Object Persistence |
| `TomAttachment` | Messaging |
| `TomAuditAction` | Audit |
| `TomAuditActor` | Audit |
| `TomAuditAnchor` | Audit |
| `TomAuditAnchorCheck` | Audit |
| `TomAuditAnchorCheckFailure` | Audit |
| `TomAuditAnchorMonitor` | Audit |
| `TomAuditAnchorPublisher` | Audit |
| `TomAuditAnchorReport` | Audit |
| `TomAuditAnchorSigner` | Audit |
| `TomAuditAnchorStatus` | Audit |
| `TomAuditAnchorStore` | Audit |
| `TomAuditAnchorVerification` | Audit |
| `TomAuditAnchorVerificationJob` | Audit |
| `TomAuditAnchorVerifier` | Audit |
| `TomAuditBypass` | Audit |
| `TomAuditChainReader` | Audit |
| `TomAuditChainVerification` | Audit |
| `TomAudited` | Audit |
| `TomAuditEntry` | Audit |
| `TomAuditException` | Audit |
| `tomAuditGenesisHash` | Audit |
| `TomAuditHeadRow` | Audit |
| `TomAuditOutcome` | Audit |
| `TomAuditPolicy` | Audit |
| `TomAuditQuery` | Audit |
| `TomAuditQueryResult` | Audit |
| `TomAuditQuestion` | Audit Reports |
| `TomAuditQuestionFilter` | Audit Reports |
| `TomAuditQuestionRow` | Audit Reports |
| `TomAuditQuestionStore` | Audit Reports |
| `TomAuditRecord` | Audit |
| `TomAuditRecordIdGenerator` | Audit |
| `tomAuditRedactedPlaceholder` | Audit |
| `TomAuditReportDelivery` | Audit Reports |
| `TomAuditReportException` | Audit Reports |
| `TomAuditReports` | Audit Reports |
| `TomAuditReportsErrorHandler` | Audit Reports |
| `TomAuditReportsServer` | Audit Reports |
| `TomAuditSeqRow` | Audit |
| `TomAuditSink` | Audit |
| `TomAuditTrail` | Audit |
| `TomAuditTrailRow` | Audit |
| `TomAuditTrailSource` | Audit Reports |
| `TomAuditTriggerRow` | Audit |
| `TomAuditView` | Audit Reports |
| `TomAuditViewEntry` | Audit Reports |
| `TomAuditViewResult` | Audit Reports |
| `TomAuditWatchedChain` | Audit |
| `TomAuditWriteOnceCheck` | Audit |
| `TomAuditWriterRow` | Audit Reports |
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
| `TomAwsCredentialsSource` | File Storage |
| `TomAwsV4Signer` | File Storage |
| `TomBaseServerConfiguration` | Configuration |
| `TomBinaryOperator` | Object Persistence |
| `TomBlindIndex` | Object Persistence |
| `TomBlindIndexNormalization` | Object Persistence |
| `TomBlobChunkRow` | File Storage |
| `TomBlobContent` | File Storage |
| `TomBlobContentRow` | File Storage |
| `TomBlobDigest` | File Storage |
| `TomBlobExportStore` | Export |
| `tomBlobKeyUnder` | File Storage |
| `TomBlobLedger` | File Storage |
| `TomBlobLedgerEntry` | File Storage |
| `TomBlobLedgerEntryRow` | File Storage |
| `TomBlobManifestRow` | File Storage |
| `TomBlobMigration` | Object Persistence |
| `TomBlobMigrationException` | Object Persistence |
| `TomBlobMigrationReport` | Object Persistence |
| `TomBlobOrphanSweep` | Object Persistence |
| `TomBlobOrphanSweepReport` | Object Persistence |
| `TomBlobQuota` | File Storage |
| `TomBlobRange` | File Storage |
| `TomBlobReferenceCountRow` | File Storage |
| `TomBlobReferenceSource` | Object Persistence |
| `TomBlobStore` | File Storage |
| `TomBlobStoreBackend` | File Storage |
| `TomBlobStoreBackendFactory` | File Storage |
| `TomBlobStoreInfo` | File Storage |
| `TomBlobStoreOperation` | File Storage |
| `TomBlobUsage` | File Storage |
| `TomBlobUsageRow` | File Storage |
| `TomBoolConfig` | Configuration |
| `TomBusInvalidationChannel` | Cache |
| `TomBusRelay` | Messaging |
| `tomBusRelayJobName` | Messaging |
| `TomCache` | Cache |
| `TomCachedItemLevel` | Cache |
| `TomCacheEntry` | Cache |
| `TomCacheException` | Cache |
| `TomCacheInvalidateMessage` | Cache |
| `TomCacheInvalidation` | Cache |
| `TomCacheInvalidationRow` | Cache |
| `TomCacheInvalidator` | Cache |
| `TomCacheManager` | Cache |
| `TomCacheRemoveMessage` | Cache |
| `TomCacheRetrieveMessage` | Cache |
| `TomCacheStoreMessage` | Cache |
| `TomChartType` | Export |
| `TomClassScanResult` | Endpoints |
| `TomClientAddress` | Rate Limiting |
| `TomColumnAuthorization` | Object Persistence |
| `TomColumnAuthorizationException` | Object Persistence |
| `TomColumnAuthResolver` | Object Persistence |
| `TomColumnInformation` | Object Persistence |
| `TomColumnType` | Export |
| `TomColumnWriteDecision` | Object Persistence |
| `TomComponentReference` | Endpoints |
| `TomCompositeKey` | Object Persistence |
| `TomConfig` | Configuration |
| `TomConfigurationException` | Configuration |
| `TomConnectionFactory` | Datasources |
| `TomConnectionPool` | Datasources |
| `TomConnectionPoolException` | Datasources |
| `TomConnectionPoolSettings` | Datasources |
| `tomConsumesForm` | Endpoints |
| `tomConsumesMultipartForm` | Endpoints |
| `TomContentSecurityPolicyHook` | Server |
| `TomCors` | Endpoints |
| `TomCorsException` | Endpoints |
| `TomCount` | Datasources |
| `TomCountResult` | Object Persistence |
| `TomCredentialOutcome` | Server |
| `TomCsvRenderer` | Export |
| `TomDartType` | Object Persistence |
| `TomDatabaseBlobStore` | File Storage |
| `TomDatabaseBlobStoreBackend` | File Storage |
| `TomDataKeyPurpose` | Object Persistence |
| `TomDataKeyRecord` | Object Persistence |
| `TomDataKeyRow` | Object Persistence |
| `TomDataKeyState` | Object Persistence |
| `TomDataKeyStore` | Object Persistence |
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
| `TomDataSubject` | Privacy |
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
| `TomDecisionRow` | Transactions |
| `TomDeduplicatingBlobStore` | File Storage |
| `tomDefaultAuthenticationMiddleware` | Server |
| `TomDefaultErrorHandler` | Endpoints |
| `TomDefaultHealthAnalyzer` | Health Check |
| `TomDelegationMode` | Authorization |
| `TomDelegationResolver` | Authorization |
| `TomDelete` | Datasources |
| `TomDeliveredCode2FAService` | Authentication |
| `TomDeliveryCallback` | Messaging |
| `TomDeliveryCallbackRequest` | Messaging |
| `TomDeliveryCallbackVerifier` | Messaging |
| `TomDeliveryCorrelation` | Messaging |
| `TomDeliveryException` | Messaging |
| `TomDeliveryOutcome` | Messaging |
| `TomDeliveryReceipt` | Messaging |
| `TomDeliveryReport` | Messaging |
| `TomDeliveryReportEndpoint` | Messaging |
| `TomDeliveryReportProtocol` | Messaging |
| `TomDeliveryReportRow` | Messaging |
| `TomDeliveryReportServer` | Messaging |
| `TomDeliveryReportService` | Messaging |
| `TomDeliveryReportStore` | Messaging |
| `TomDeliveryState` | Messaging |
| `TomDirectoryBlobStore` | File Storage |
| `TomDirectoryBlobStoreBackend` | File Storage |
| `TomDirectoryExportStore` | Export |
| `TomDoubleConfig` | Configuration |
| `TomDummyAuthenticationService` | Authentication |
| `TomEmailCode2FAService` | Authentication |
| `TomEmailRequest` | Messaging |
| `TomEmailService` | Messaging |
| `TomEncrypted` | Object Persistence |
| `TomEndpoint` | Endpoints |
| `TomEndpointBase` | Endpoints |
| `TomEndpointCredentials` | Server |
| `TomEndpointHandler` | Endpoints |
| `TomEndpointHandlerException` | Endpoints |
| `TomEndpointPipelineException` | Endpoints |
| `TomEndpointRouteKey` | Endpoints |
| `TomEndpointRouting` | Endpoints |
| `TomEndpointRoutingInfo` | Endpoints |
| `TomEntityChange` | Object Persistence |
| `TomEntityChangeKind` | Object Persistence |
| `TomEntityChangeListener` | Object Persistence |
| `TomEntityId` | Object Persistence |
| `TomEntityLifecycle` | Object Persistence |
| `TomEntityLifecycleException` | Object Persistence |
| `TomEntityListener` | Object Persistence |
| `TomEntitySchemaReader` | Database Migration |
| `TomEnvFile` | Command Line |
| `TomErasure` | Privacy |
| `TomErasureCount` | Privacy |
| `TomErasureReport` | Privacy |
| `tomErrorEnvelope` | Little Things |
| `TomErrorHandler` | Endpoints |
| `tomErrorResponse` | Little Things |
| `TomExclusiveCanonicalizer` | Authentication |
| `TomExists` | Object Persistence |
| `TomExportEmailDelivery` | Export |
| `TomExportEmailMode` | Export |
| `TomExportException` | Export |
| `TomExportFormats` | Export |
| `TomExportQuota` | Export |
| `TomExportRecord` | Export |
| `TomExportRecordRow` | Export |
| `TomExportRegister` | Export |
| `TomExportRetention` | Export |
| `TomExportService` | Export |
| `TomExportStore` | Export |
| `TomExportStoreOperation` | Export |
| `TomExportUsage` | Export |
| `TomExportUsageRow` | Export |
| `TomExternalIdentity` | Authentication |
| `TomExternalIdentityDirectory` | Authentication |
| `TomExternalIdentityLink` | Authentication |
| `TomExternalIdentityLinkRepository` | Authentication |
| `TomExternalIdentityStore` | Authentication |
| `TomExternalIdentityToken` | Authentication |
| `TomExternalIdentityTokenRepository` | Authentication |
| `TomExternalProvider` | Authentication |
| `TomExternalRoleMapping` | Authentication |
| `TomExternalTenancyMapping` | Authentication |
| `TomFcmPushProtocol` | Messaging |
| `TomFcmServiceAccountCredential` | Messaging |
| `TomFeatureFlagsServer` | Configuration |
| `TomFieldEncryption` | Object Persistence |
| `TomFieldEncryptionException` | Object Persistence |
| `TomFieldKeyring` | Object Persistence |
| `TomFieldMappedDeliveryReportProtocol` | Messaging |
| `TomFieldMappedPushProtocol` | Messaging |
| `TomFieldMappedSmsProtocol` | Messaging |
| `TomFieldReencryption` | Object Persistence |
| `TomFileAuditAnchorStore` | Audit |
| `TomFileAuditSink` | Audit |
| `TomFileEndpoint` | Endpoints |
| `TomFileMessageTransport` | Messaging |
| `TomFileReference` | Object Persistence |
| `TomFileReferenceKeys` | Object Persistence |
| `TomFileRepository` | Object Persistence |
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
| `TomFrameworkReadinessAnalyzer` | Health Check |
| `TomFrameworkSchemaCheck` | Database Migration |
| `TomFrameworkTable` | Datasources |
| `TomGeneratedQuery` | Datasources |
| `TomGracefulShutdown` | Server |
| `TomGradedAccessControlInformation` | Authorization |
| `TomGroupedRow` | Object Persistence |
| `TomGroupedSelect` | Object Persistence |
| `TomHealthAnalyzer` | Health Check |
| `TomHealthCheck` | Health Check |
| `TomHealthCheckCancelled` | Health Check |
| `TomHealthServer` | Health Check |
| `TomHealthService` | Health Check |
| `TomHealthStatus` | Health Check |
| `TomHealthVerdict` | Health Check |
| `TomHistory` | Object Persistence |
| `TomHistoryEntry` | Object Persistence |
| `TomHistoryMeta` | Object Persistence |
| `TomHttp1PushExchange` | Messaging |
| `TomHttp2PushExchange` | Messaging |
| `TomHttpOAuthTokenTransport` | Authentication |
| `TomHttpServiceLoginTransport` | Authentication |
| `TomIdempotency` | Endpoints |
| `TomIdempotencyClaim` | Endpoints |
| `TomIdempotencyException` | Endpoints |
| `TomIdempotencyRecord` | Endpoints |
| `TomIdempotencyRow` | Endpoints |
| `TomIdempotencyScope` | Endpoints |
| `TomIdempotencyStore` | Endpoints |
| `TomIdempotent` | Endpoints |
| `TomInbox` | Messaging |
| `TomInboxException` | Messaging |
| `TomInboxOutcome` | Messaging |
| `TomInboxRow` | Messaging |
| `TomInformationSchemaColumnRow` | Database Migration |
| `TomInMemorySpanExporter` | Tracing |
| `TomInSubquery` | Object Persistence |
| `TomIntConfig` | Configuration |
| `TomInvalidationChannel` | Cache |
| `TomInvalidationKind` | Cache |
| `TomInvalidationLog` | Cache |
| `tomInvalidationTopic` | Cache |
| `TomIssuedApiKey` | Authentication |
| `TomItemAuthority` | Item Authorization |
| `TomItemAuthorityScopeSource` | Item Authorization |
| `TomItemAuthorizationCache` | Cache |
| `TomItemAuthorizationChange` | Cache |
| `TomItemAuthorizationChangePage` | Cache |
| `TomItemAuthorizationClient` | Item Authorization |
| `TomItemAuthorizationException` | Item Authorization |
| `TomItemAuthorizationFeedExpiredException` | Cache |
| `TomItemAuthorizationFeedFollower` | Cache |
| `TomItemAuthorizationRecord` | Item Authorization |
| `TomItemAuthorizationWebhook` | Cache |
| `TomItemAuthorizationWebhookException` | Cache |
| `TomItemShareRequest` | Item Authorization |
| `TomJobBacklogRow` | Scheduling |
| `TomJobPauseRow` | Scheduling |
| `TomJobRunArchiveRow` | Scheduling |
| `TomJobRunRow` | Scheduling |
| `TomJobRunWindowRow` | Scheduling |
| `TomJwksServer` | Authentication |
| `TomJwksService` | Authentication |
| `TomJwtAlgorithm` | Authentication |
| `TomJwtKey` | Authentication |
| `TomJwtKeyException` | Authentication |
| `TomJwtSigning` | Authentication |
| `TomJwtSigningKey` | Authentication |
| `TomKeyEncryptionKey` | Object Persistence |
| `TomKeyEncryptionKeyFactory` | Object Persistence |
| `TomLeaseRow` | Scheduling |
| `TomLiteralSelect` | Datasources |
| `TomLocalInvalidationChannel` | Cache |
| `TomLocalizedTextResources` | Resources |
| `tomLoggingMiddleware` | Server |
| `TomLoginException` | Authentication |
| `TomMapSecretsProvider` | Configuration |
| `TomMemory2FAEnrolmentStore` | Authentication |
| `TomMemory2FAGraceStore` | Authentication |
| `TomMemoryApiKeyStore` | Authentication |
| `TomMemoryAuditAnchorStore` | Audit |
| `TomMemoryAuditQuestionStore` | Audit Reports |
| `TomMemoryAuditSink` | Audit |
| `TomMemoryAuditTrailSource` | Audit Reports |
| `TomMemoryBlobLedger` | File Storage |
| `TomMemoryBlobStore` | File Storage |
| `TomMemoryBlobStoreBackend` | File Storage |
| `TomMemoryDataKeyStore` | Object Persistence |
| `TomMemoryDecisionLog` | Transactions |
| `TomMemoryDeliveryReportStore` | Messaging |
| `TomMemoryExportRegister` | Export |
| `TomMemoryExportStore` | Export |
| `TomMemoryExternalIdentityStore` | Authentication |
| `TomMemoryIdempotencyStore` | Endpoints |
| `TomMemoryInbox` | Messaging |
| `TomMemoryInvalidationLog` | Cache |
| `TomMemoryMessageTransport` | Messaging |
| `TomMemoryOAuthTokenStore` | Authentication |
| `TomMemoryRateLimiter` | Rate Limiting |
| `TomMemorySagaStore` | Transactions |
| `TomMemoryScimStore` | Authentication |
| `TomMemorySubjectKeyStore` | Privacy |
| `TomMemorySuppressionList` | Messaging |
| `TomMessage` | Messaging |
| `TomMessageBody` | Messaging |
| `TomMessageChannel` | Messaging |
| `TomMessageOutbox` | Messaging |
| `TomMessageRouter` | Messaging |
| `TomMessageTransport` | Messaging |
| `TomMessagingException` | Messaging |
| `TomMethodMetadata` | Endpoints |
| `tomMetricsEndpointMiddleware` | Metrics |
| `TomMigrationArtifact` | Database Migration |
| `TomMigrationFileName` | Database Migration |
| `TomMigrationRepair` | Database Migration |
| `TomMigrationRun` | Database Migration |
| `TomMigrationRunState` | Database Migration |
| `TomMigrationScript` | Database Migration |
| `TomMimeEncoder` | Messaging |
| `tomMimeLineEnding` | Messaging |
| `tomMimeMaxLineLength` | Messaging |
| `TomMultipartForm` | Endpoints |
| `TomMutualTls` | Server |
| `TomMutualTlsClientFactory` | Server |
| `TomMutualTlsException` | Server |
| `TomNoOpMessageTransport` | Messaging |
| `TomNotification` | Notifications |
| `TomNotificationAudience` | Notifications |
| `TomNotificationCadence` | Notifications |
| `TomNotificationCatalog` | Notifications |
| `TomNotificationChoice` | Notifications |
| `TomNotificationChoiceOrigin` | Notifications |
| `TomNotificationDelivery` | Notifications |
| `TomNotificationDeliveryOutcome` | Notifications |
| `TomNotificationDigestItem` | Notifications |
| `tomNotificationDigestJobName` | Notifications |
| `TomNotificationDigestRendering` | Notifications |
| `TomNotificationDigests` | Notifications |
| `TomNotificationDispatcher` | Notifications |
| `TomNotificationDispatchReport` | Notifications |
| `TomNotificationException` | Notifications |
| `TomNotificationPreferences` | Notifications |
| `TomNotificationPreferenceSource` | Notifications |
| `TomNotificationPreferencesServer` | Notifications |
| `TomNotificationRecipient` | Notifications |
| `TomNotificationRenderer` | Notifications |
| `TomNotificationRendering` | Notifications |
| `TomNotificationType` | Notifications |
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
| `TomOpenApiServer` | Endpoints |
| `TomOpenApiService` | Endpoints |
| `TomOperator` | Datasources |
| `TomOptimisticLockException` | Object Persistence |
| `TomOrganizationFallback` | Authentication |
| `TomOtelTracer` | Tracing |
| `TomOtlpExportException` | Metrics |
| `TomOtlpHttpTransport` | Metrics |
| `TomOtlpMetricsExporter` | Metrics |
| `tomOtlpMetricsJson` | Metrics |
| `tomOutboxJobName` | Messaging |
| `TomPageRequest` | Object Persistence |
| `TomPdfRenderer` | Export |
| `TomPermanentDeliveryException` | Messaging |
| `TomPersistent2FAEnrolmentStore` | Authentication |
| `TomPersistentExternalIdentityStore` | Authentication |
| `TomPersistentOAuthTokenStore` | Authentication |
| `TomPersonal` | Privacy |
| `TomPersonalDataModel` | Privacy |
| `TomPersonalField` | Privacy |
| `TomPreferenceDefault` | Preferences |
| `TomPreferenceDefaultRepository` | Preferences |
| `TomPreferenceDefaults` | Preferences |
| `TomPreferenceDefaultScope` | Preferences |
| `TomPreparedBranchHolder` | Transactions |
| `TomPreparedStatement` | Datasources |
| `TomPrimaryReads` | Datasources |
| `TomPrincipalDelegation` | Authorization |
| `TomPrincipalFlag2FAPolicy` | Authentication |
| `TomPrincipalResourceGrant` | Authorization |
| `TomPrincipalResourceRoleResolver` | Authorization |
| `TomPrivacy` | Privacy |
| `TomPrivacyException` | Privacy |
| `tomProbePaths` | Server |
| `tomProblemDetails` | Little Things |
| `tomProblemJsonContextKey` | Little Things |
| `tomProblemJsonMediaType` | Little Things |
| `TomPushCredential` | Messaging |
| `TomPushExchange` | Messaging |
| `TomPushGatewayAnswer` | Messaging |
| `TomPushGatewayRequest` | Messaging |
| `TomPushGatewayResponse` | Messaging |
| `TomPushProtocol` | Messaging |
| `TomPushRequest` | Messaging |
| `TomPushService` | Messaging |
| `TomPushSubmission` | Messaging |
| `TomPushTransport` | Messaging |
| `TomQuery` | Datasources |
| `TomQueryBuilder` | Object Persistence |
| `TomQuerySentenceCompiler` | Object Persistence |
| `TomQuerySyntaxException` | Object Persistence |
| `TomQuietHours` | Notifications |
| `TomRateLimitDecision` | Rate Limiting |
| `TomRateLimiter` | Rate Limiting |
| `TomRateLimitException` | Rate Limiting |
| `tomRateLimitMiddleware` | Rate Limiting |
| `TomRateLimitRow` | Rate Limiting |
| `TomRateLimitRule` | Rate Limiting |
| `TomRateLimits` | Rate Limiting |
| `TomRateLimitScope` | Rate Limiting |
| `TomReadinessCheck` | Health Check |
| `tomReasonPhrase` | Little Things |
| `TomRecipient` | Messaging |
| `TomRecipientKind` | Messaging |
| `TomRecoveryReport` | Transactions |
| `TomRedirect` | Endpoints |
| `tomReencryptionJobName` | Object Persistence |
| `TomReencryptionReport` | Object Persistence |
| `TomReference` | Object Persistence |
| `TomReplicaRouting` | Datasources |
| `TomRepository` | Object Persistence |
| `TomRepositoryBlobReferences` | Object Persistence |
| `TomRepositoryException` | Object Persistence |
| `TomRequestCache` | Little Things |
| `tomRequestContextMiddleware` | Server |
| `TomRequestIdException` | Server |
| `tomRequestIdHeader` | Server |
| `TomRequestIdPolicy` | Server |
| `TomRequestLogInfo` | Server |
| `tomRequestLogInfoMiddleware` | Server |
| `tomRequestMetricsMiddleware` | Metrics |
| `TomResourceDataScope` | Authorization |
| `TomResourceGrant` | Authorization |
| `TomResourceLocaleException` | Resources |
| `TomResourceScopeSource` | Object Persistence |
| `TomRetention` | Privacy |
| `TomRetentionCount` | Privacy |
| `tomRetentionJobName` | Privacy |
| `TomRetentionPolicy` | Privacy |
| `TomRole2FAPolicy` | Authentication |
| `TomRowColumnAuthorization` | Object Persistence |
| `TomRowColumnAuthResolver` | Object Persistence |
| `TomRsaAuditAnchorSigner` | Audit |
| `TomRsaAuditAnchorVerifier` | Audit |
| `TomS3BlobStore` | File Storage |
| `TomS3BlobStoreBackend` | File Storage |
| `TomSaga` | Transactions |
| `TomSagaContext` | Transactions |
| `TomSagaException` | Transactions |
| `tomSagaJobPrefix` | Transactions |
| `TomSagaOrchestrator` | Transactions |
| `TomSagaRow` | Transactions |
| `TomSagaState` | Transactions |
| `TomSagaStatus` | Transactions |
| `TomSagaStep` | Transactions |
| `TomSagaStore` | Transactions |
| `TomSagaWork` | Transactions |
| `TomSameSite` | Authentication |
| `TomSamlCertificates` | Authentication |
| `TomSamlException` | Authentication |
| `TomSamlFlow` | Authentication |
| `TomSamlIdpMetadata` | Authentication |
| `TomSamlNames` | Authentication |
| `TomSamlProviderConfig` | Authentication |
| `TomSamlProviders` | Authentication |
| `TomSamlResponseValidator` | Authentication |
| `TomSamlServer` | Authentication |
| `TomSamlService` | Authentication |
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
| `TomSchemaProvisioning` | Datasources |
| `TomSchemaTable` | Database Migration |
| `TomScimAnd` | Authentication |
| `TomScimApi` | Authentication |
| `TomScimComparison` | Authentication |
| `TomScimException` | Authentication |
| `TomScimFilter` | Authentication |
| `TomScimIdentityDirectory` | Authentication |
| `TomScimNot` | Authentication |
| `TomScimOr` | Authentication |
| `TomScimPath` | Authentication |
| `TomScimProvisioning` | Authentication |
| `TomScimResource` | Authentication |
| `TomScimResourceRow` | Authentication |
| `TomScimResourceType` | Authentication |
| `TomScimSchemas` | Authentication |
| `TomScimServer` | Authentication |
| `TomScimService` | Authentication |
| `TomScimStore` | Authentication |
| `TomScimValuePath` | Authentication |
| `TomSecretPayload` | Configuration |
| `TomSecretReference` | Configuration |
| `TomSecrets` | Configuration |
| `TomSecretsException` | Configuration |
| `TomSecretsProvider` | Configuration |
| `TomSecretsRefresh` | Configuration |
| `TomSecretSubscription` | Configuration |
| `TomSecurityHeaders` | Server |
| `TomSecurityHeadersException` | Server |
| `tomSecurityHeadersMiddleware` | Server |
| `TomSelect` | Datasources |
| `TomServer` | Server |
| `TomServerConfigResourceProvider` | Configuration |
| `TomServerException` | Little Things |
| `TomServerSelfLogin` | Authentication |
| `TomServerSelfLoginException` | Authentication |
| `TomServerSession` | Authentication |
| `TomService` | Endpoints |
| `tomService` | Endpoints |
| `TomServiceAccount` | Authentication |
| `TomServiceAccountRow` | Authentication |
| `TomServiceCredential` | Authentication |
| `TomServiceLoginResponse` | Authentication |
| `TomServiceLoginTransport` | Authentication |
| `TomSessionCookie` | Authentication |
| `TomSessionCookieException` | Authentication |
| `TomSharedItemsPage` | Item Authorization |
| `TomSharedSecretCallbackVerifier` | Messaging |
| `TomShareSubjectKind` | Item Authorization |
| `TomSigningKeyException` | Authentication |
| `TomSignInOrganization` | Authentication |
| `TomSignInOrganizationDirectory` | Authentication |
| `TomSignInOrganizations` | Authentication |
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
| `TomSoftDelete` | Object Persistence |
| `TomSortDirection` | Object Persistence |
| `TomSortField` | Object Persistence |
| `TomSqlApiKeyStore` | Authentication |
| `TomSqlAuditQuestionStore` | Audit Reports |
| `TomSqlAuditSink` | Audit |
| `TomSqlAuditTrailSource` | Audit Reports |
| `tomSqlBindParams` | Datasources |
| `tomSqlBindValue` | Datasources |
| `TomSqlBlobLedger` | File Storage |
| `TomSqlBranch` | Datasources |
| `tomSqlBranchId` | Datasources |
| `tomSqlBranchOpenedAt` | Datasources |
| `TomSqlConnectionLostException` | Datasources |
| `TomSqlDataKeyStore` | Object Persistence |
| `TomSqlDatasource` | Datasources |
| `TomSqlDatasourceException` | Datasources |
| `TomSqlDatasourceRepository` | Object Persistence |
| `TomSqlDecisionLog` | Transactions |
| `TomSqlDeliveryReportStore` | Messaging |
| `TomSqlExportRegister` | Export |
| `TomSqlFailureMode` | Datasources |
| `TomSqlIdempotencyStore` | Endpoints |
| `TomSqlInbox` | Messaging |
| `TomSqlInvalidationChannel` | Cache |
| `TomSqlJobStore` | Scheduling |
| `TomSqlLeaseLock` | Scheduling |
| `TomSqlLexer` | Datasources |
| `TomSqlLink` | Datasources |
| `TomSqlMigrationAdaptor` | Database Migration |
| `TomSqlMigrationException` | Database Migration |
| `TomSqlOAuthStateStore` | Authentication |
| `tomSqlOwnsBranch` | Datasources |
| `TomSqlPreparedStatement` | Datasources |
| `TomSqlRateLimiter` | Rate Limiting |
| `TomSqlResult` | Datasources |
| `TomSqlResultValues` | Datasources |
| `TomSqlRow` | Datasources |
| `TomSqlSagaStore` | Transactions |
| `TomSqlSchedulerNodes` | Scheduling |
| `TomSqlScimStore` | Authentication |
| `TomSqlSubjectKeyStore` | Privacy |
| `TomSqlSuppressionList` | Messaging |
| `TomSqlSyncLog` | Sync |
| `TomSqlTwoPhaseRecovery` | Datasources |
| `TomSqlTypeFamily` | Datasources |
| `TomSqlTypeFamilyCompatibility` | Database Migration |
| `TomStandardSqlDialect` | Datasources |
| `TomStatementOutcome` | Datasources |
| `TomStaticPushCredential` | Messaging |
| `TomStatusMappingErrorHandler` | Endpoints |
| `TomStorageException` | File Storage |
| `TomStoredBlob` | File Storage |
| `TomStoredExport` | Export |
| `TomStringConfig` | Configuration |
| `TomSubjectAccess` | Privacy |
| `TomSubjectField` | Privacy |
| `TomSubjectKeyRecord` | Privacy |
| `TomSubjectKeyRow` | Privacy |
| `TomSubjectKeys` | Privacy |
| `TomSubjectKeyStore` | Privacy |
| `TomSubquery` | Object Persistence |
| `TomSuppressedAddress` | Messaging |
| `TomSuppressionList` | Messaging |
| `TomSuppressionRow` | Messaging |
| `TomSync` | Sync |
| `TomSyncChangeIdRow` | Sync |
| `TomSyncChangeRow` | Sync |
| `TomSyncErrorHandler` | Sync |
| `TomSyncException` | Sync |
| `TomSyncRejection` | Sync |
| `TomSyncSequenceRow` | Sync |
| `TomSyncServer` | Sync |
| `TomTabularChart` | Export |
| `TomTabularColumn` | Export |
| `TomTabularRenderer` | Export |
| `TomTabularResult` | Export |
| `TomTabularRow` | Export |
| `TomTabularSection` | Export |
| `TomTemplatedMessageService` | Messaging |
| `TomTemplatedNotificationRenderer` | Notifications |
| `TomTenancy` | Tenancy |
| `TomTenancyException` | Tenancy |
| `TomTenant` | Tenancy |
| `TomTenantHeaderResolver` | Tenancy |
| `TomTenantHostResolver` | Tenancy |
| `TomTenantIsolation` | Tenancy |
| `TomTenantOwned` | Object Persistence |
| `TomTenantPathResolver` | Tenancy |
| `TomTenantProviderSets` | Authentication |
| `TomTenantResolution` | Tenancy |
| `TomTenantResolver` | Tenancy |
| `TomTextLocale` | Resources |
| `TomTlsConnectionInfo` | Server |
| `TomTotp2FAService` | Authentication |
| `TomTotpSecretResolver` | Authentication |
| `TomTracingException` | Tracing |
| `TomTransaction` | Transactions |
| `TomTransactional` | Endpoints |
| `TomTransactionDecisionLog` | Transactions |
| `TomTransactionException` | Transactions |
| `TomTransactionManager` | Transactions |
| `TomTransactionOutcome` | Transactions |
| `TomTransactionParticipant` | Transactions |
| `TomTransactionRecovery` | Transactions |
| `TomTransactionRecoveryException` | Transactions |
| `TomTransactionResult` | Transactions |
| `TomTransientDeliveryException` | Messaging |
| `TomTwilioCallbackVerifier` | Messaging |
| `TomTwoPhaseRecoverable` | Transactions |
| `TomTypedPersistenceBase` | Datasources |
| `TomTypePersistenceInfo` | Datasources |
| `TomUnaryOperator` | Object Persistence |
| `TomUntracedClient` | Tracing |
| `TomUpdate` | Datasources |
| `TomUserPreference` | Preferences |
| `TomUserPreferenceException` | Preferences |
| `TomUserPreferenceRepository` | Preferences |
| `TomUserPreferences` | Preferences |
| `TomUserPreferencesErrorHandler` | Preferences |
| `TomUserPreferencesNotificationSource` | Notifications |
| `TomUserPreferencesServer` | Preferences |
| `TomUserTwoFactorEnrolment` | Authentication |
| `TomUserTwoFactorEnrolmentRepository` | Authentication |
| `tomVendorValueAt` | Messaging |
| `TomVersion` | Object Persistence |
| `TomVonageCallbackVerifier` | Messaging |
| `TomVonageSignatureMethod` | Messaging |
| `tomWantsProblemJson` | Little Things |
| `TomWebAuthn2FAService` | Authentication |
| `TomWebAuthnRegisteredCredential` | Authentication |
| `TomWebAuthnSoftwareAuthenticator` | Authentication |
| `TomWebAuthnVerifiedAssertion` | Authentication |
| `TomWebAuthnVerifier` | Authentication |
| `TomWebhookSettings` | Messaging |
| `TomWebhookTransport` | Messaging |
| `TomWebSocketConnection` | Endpoints |
| `TomWebSocketEndpoint` | Endpoints |
| `TomWebSocketException` | Endpoints |
| `TomXlsxRenderer` | Export |
| `TomXmlDsig` | Authentication |
| `TomXmlSignatureVerifier` | Authentication |
| `TomYaml` | Configuration |
| `TruthPredicate` | Object Persistence |
| `unknownFrameworkColumns` | Datasources |
| `verifyAgainstAnchor` | Audit |
| `verifyAuditChain` | Audit |
| `verifyBearerToken` | Authentication |
