# Tom Core Server API Reference: Server Module

The HTTP entry point of a Tom server application: the `TomServer` that assembles
a shelf pipeline (context setup, error handling, authentication, logging) in
front of the endpoint router and binds it to a socket, plus the middleware,
helpers, and per-request state that make up that pipeline, and the graceful
shutdown that stops it on SIGTERM.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomRequestLogInfo](#tomrequestloginfo)
  - [TomServer](#tomserver)
  - [TomEndpointCredentials](#tomendpointcredentials)
  - [TomGracefulShutdown](#tomgracefulshutdown)
  - [TomRequestIdPolicy](#tomrequestidpolicy)
  - [TomRequestIdException](#tomrequestidexception)
- [Enums](#enums)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Sources: `lib/src/tomserver/server/server.dart`,
`lib/src/tomserver/server/graceful_shutdown.dart`,
`lib/src/tomserver/server/request_ids.dart`.

`TomServer` is built from a `TomBaseServerConfiguration`. Its `start` method
first applies the `httpClient` configuration key to the framework's outgoing
HTTP calls (`configureHttpClients`), the `requestIds` key to the request-id
policy (`configureRequestIds`) and the `idempotency` key to the
idempotency-key store (`configureIdempotency`), installs the field-encryption
keyring from the `fieldEncryption` key (`configureFieldEncryption`) and the
privacy module's subject keys from the `privacy` key (`configurePrivacy`),
applies the `transactions` key — the two-phase decision log, and a recovery of
the prepared branches a dead process left (`recoverTransactions`) — then logs
the deployment in as
itself — `TomServerSelfLogin.loginAndInstall`, which installs the
`TomServerPrincipal` that caps every user's grants, and which aborts the start
with no socket bound when a configured credential is refused — initialises the endpoint `Router` (via `TomEndpointRouting`), composes a
shelf `Pipeline` — the shutdown gate (`TomGracefulShutdown.middleware`),
`tomRequestLogInfoMiddleware` (seeds a new
`TomRequestLogInfo` per request), the metrics module's
`tomMetricsEndpointMiddleware` (when `metricsEndpoint` is on) and
`tomRequestContextMiddleware` (continues or starts the W3C trace and takes the
request id `TomRequestIdPolicy.current` chooses), `tomRequestMetricsMiddleware`, `tomLoggingMiddleware`, an outer
error layer,
`tomDefaultAuthenticationMiddleware`, `tomRateLimitMiddleware` (the ratelimit module's) and an inner error layer — optionally wraps the router in a `Cascade` with
pre/post handlers, binds the socket (with TLS unless `noSsl`), and registers
the server's graceful shutdown for SIGTERM and SIGINT.

`TomGracefulShutdown` is what the server does between SIGTERM and exiting:
`GET /ready` answers `503`, the listener closes and the gate refuses new
requests with `503` and `Connection: close` while passing the probe paths
(`tomProbePaths`), every started scheduler is stopped and the requests and runs
in flight get the grace period to finish, the outboxes and schedulers are
closed so their leases are released, and the data sources close their pools.
`TomServer.gracefulShutdown` is the server's instance, configured by
`shutdownGracePeriodSeconds` and `shutdownReadinessDelaySeconds`;
`TomServer.shutdown` runs it without a signal. See
[server.md](../server.md#graceful-shutdown).

The module exposes the composable middleware as top-level functions
(`contextSetupMiddleware`, `tomRequestLogInfoMiddleware`,
`tomRequestContextMiddleware`, `tomDefaultAuthenticationMiddleware`,
`tomLoggingMiddleware`), the response header the request id is echoed in
(`tomRequestIdHeader`), a credential helper (`extractAuthentication`) with the
`TomCredentialOutcome` it reports, `TomEndpointCredentials` — the paths whose
`Authorization` header the credential helper leaves to the endpoint — and a
`noopHandler`. Per-request state travels in the request context
(`TomRequestLogInfo`), the request zone, and — because the authentication
middleware also opens a `TomTransactionManager.runInTransactionScope` — the
current transaction. The zone-carried correlation id is the kernel's
`TomRequestId`: `tomRequestContextMiddleware` sets the one `TomRequestIdPolicy`
chooses — the configured request-id header from a trusted proxy, when the
kernel's `TomRequestId.isValid` accepts it, else the request's trace id, the
caller's when its `traceparent` is valid — and
`tomDefaultAuthenticationMiddleware` carries it into `zoneValues`. A malformed
header of either kind is ignored, never refused. `TomRequestIdPolicy.configure`
sets the policy from the `requestIds` key and throws a `TomRequestIdException`
keyed `server.request_ids.config.invalid` for a value of the wrong shape. See
[server.md](../server.md#request-ids).

## Class Hierarchy

```text
TomRequestLogInfo        (standalone)
TomServer                (standalone)
TomEndpointCredentials   (abstract final, statics only)
TomGracefulShutdown      (standalone)
TomRequestIdPolicy       (final, standalone)
TomServerException  (little_things)
    └── TomRequestIdException
```

All classes but `TomRequestIdException` are standalone (no Tom base class).

## Classes

### TomRequestLogInfo

Per-request logging state carried in the shelf request context.
`tomRequestLogInfoMiddleware` seeds a new one under `contextName` for every
request; `tomLoggingMiddleware` reads it to decide whether to emit the
access-log line and mark it logged.

#### Constructors

```dart
TomRequestLogInfo()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `contextName` | `static const String` | The request-context key under which the `TomRequestLogInfo` is stored (`"loggingInfo"`). |
| `hasBeenLogged` | `bool` | Whether the access-log line for this request has already been emitted. |
| `shouldBeLogged` | `bool` | Whether this request should produce an access-log line at all. |
| `route` | `String?` | The pattern of the endpoint that served the request (`/tasks/<id>`), set by the endpoint pipeline; `null` while no endpoint has matched. `tomRequestMetricsMiddleware` labels the request series with it, `unmatched` when it is `null`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* Compact `should=`/`has=`/`route=` description. |

### TomServer

The HTTP entry point of a Tom server application. Built from a
`TomBaseServerConfiguration`, it assembles a shelf `Pipeline` in front of the
endpoint `Router` and binds it to a socket in `start`.

#### Constructors

```dart
TomServer(TomBaseServerConfiguration configuration)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `configuration` | `TomBaseServerConfiguration` | The configuration that drives binding, TLS, and pipeline composition. |
| `securityContext` | `SecurityContext?` | The TLS context the server is serving with, or `null` for plaintext. Built by `start()` from the configuration's certificate chain and private key, so — like `router` — it is a post-`start()` handle and reads `null` on a server that has not been started. `configuration.noSsl` is what answers "was TLS asked for?" beforehand. |
| `router` | `Router?` | The endpoint router, initialised during `start`. |
| `errorHandler` | `Response? Function(Request, Object, StackTrace)` | Maps a thrown error to an error response (HTTP 500) marked `x-tom-error: true`, built by [`tomErrorResponse`](api_summary_little_things.md#tomerrorresponse); overridable via the configuration. The body is [`tomErrorEnvelope`](api_summary_little_things.md#tomerrorenvelope), declared `Content-Type: application/json` — the package's single definition of the wire error shape, which this handler renders and does not define — or, for a request whose `Accept` names `application/problem+json`, the same fields as an RFC 9457 problem document declared `application/problem+json`. |
| `authenticationErrorHandler` | `Response? Function(Request, Object, StackTrace)?` | Error handler applied by the outer pipeline layer; defaults to the configuration's handler, falling back to `errorHandler`. |
| `loggingMiddleware` | `Middleware` | The middleware that emits the per-request access log (`late`; from the configuration). |
| `gracefulShutdown` | `TomGracefulShutdown` | The graceful shutdown of this server (`late final`), built from `shutdownGracePeriodSeconds` and `shutdownReadinessDelaySeconds`. `start` hands it the bound socket, puts its `middleware()` outermost in the pipeline and registers it with `tomShutdownCleanup` for SIGTERM (not on Windows) and SIGINT, raising the cleanup's phase timeout to cover the readiness delay and the grace period, and setting `exitAfterSignalShutdown` when `exitOnShutdownSignal` is on. |
| `httpClientConfigurationKey` | `static const String` | `'httpClient'`, the configuration key holding the resilience policies of outgoing HTTP calls that `configureHttpClients` applies. |
| `idempotencyConfigurationKey` | `static const String` | `'idempotency'`, the configuration key holding the idempotency-key settings — the store's data source and table, the retention, the in-progress timeout — that `configureIdempotency` applies. |
| `metricsExporter` | `TomOtlpMetricsExporter?` | The exporter pushing metrics to the configured OTLP receiver, or `null` when `otlpEndpoint` names none. Created and started by `start`, registered with the shutdown cleanup, which closes it with a final push. A post-`start()` handle like `router`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `warnOnDevelopmentTlsMaterial` | `void warnOnDevelopmentTlsMaterial()` | Warns when this server is about to serve TLS with the checked-in development pair, naming which half is still at its default. Called by `start` before it builds the `SecurityContext`. Silent when `noSsl` is set, since nothing is served over TLS. Nothing refuses to start: an opt-in flag would cost every local TLS run an extra setting. Public and separate from `start` because `start` binds a socket and returns nothing, so a property of the boot is otherwise unobservable. |
| `warnOnUnenforcedResourceKeys` | `void warnOnUnenforcedResourceKeys()` | Warns when this server is about to serve with resource-key grants unenforced (`tom.protection.resourceKeys` off, the default) outside a development or test environment, naming the setting that changes it. Called by `start` before the socket is bound. Silent when enforcement is on or the environment is development or test. Nothing refuses to start: the default stays off because enforcing refuses every undeclared endpoint of an application with no grants configured. |
| `start` | `Future<HttpServer> start()` | Applies the `httpClient` configuration key to the outgoing HTTP calls (`configureHttpClients`), the `requestIds` key to the request-id policy (`configureRequestIds`) and the `idempotency` key to the idempotency-key store (`configureIdempotency`) before anything else, so the deployment's own login runs under the configured policies, awaits the keyring the `fieldEncryption` key describes (`configureFieldEncryption`), installs the subject keys the `privacy` key describes (`configurePrivacy`), and applies the `transactions` key — the decision log, and with `recoverOnStart` a recovery of the prepared branches a dead process left (`recoverTransactions`); then logs the deployment in as itself (`TomServerSelfLogin.loginAndInstall`), warns if the TLS material is still the development pair, installs the rate limits the `rateLimits` configuration key describes when none were installed (`TomRateLimits.fromConfiguration`), starts `metricsExporter` when `otlpEndpoint` is set, applies `logFormat` (`applyLogFormat`), installs a `TomFrameworkReadinessAnalyzer` on `GET /ready` when `frameworkReadiness` is on and the readiness analyzer is still the default one, initialises the router, composes the pipeline, builds TLS, resolves the listen address, and binds the socket. The future completes **when the socket is listening**, with the bound `HttpServer` — so a bind failure rejects it rather than surfacing as an unhandled asynchronous error, and the socket can be closed by its opener. A deployment that configured a service credential and cannot log in has the error rethrown and **no socket is bound**; one that configured none is unaffected. Awaiting is optional: the bound socket keeps the isolate alive on its own. Once bound, the socket is handed to `gracefulShutdown`, which is registered for SIGTERM and SIGINT. |
| `shutdown` | `Future<void> shutdown()` | Shuts this server down gracefully — `gracefulShutdown.shutdown()`: readiness off, no new requests, the requests and scheduled work in flight finished within the grace period, leases released and pools closed. Idempotent. A signal runs it through `tomShutdownCleanup`; calling it directly never ends the process. |
| `configureHttpClients` | `static void configureHttpClients([TomServerConfigResourceProvider? config])` | Applies the `httpClientConfigurationKey` map of `config` — the server configuration (`TomServerConfigResourceProvider.getServerConfig()`) when omitted — to the kernel's `TomHttpResilience.configure`: the timeout, retry, circuit-breaker and bulkhead defaults of every outgoing framework call, and the policies of the destinations it names. Without the key nothing changes and the kernel's defaults stand, a 30-second timeout among them. Throws a `TomHttpResilienceException` keyed `http.client.config.invalid` when the value is not a map or a setting has the wrong shape, before anything is applied. Called by `start`; public and static so a boot can apply the settings before `TomSecrets.load` reaches a secret store. See [configuration.md](../configuration.md#outgoing-http-calls). |
| `configureRequestIds` | `static void configureRequestIds([TomServerConfigResourceProvider? config])` | Applies the `TomRequestIdPolicy.configurationKey` (`requestIds`) map of `config` — the server configuration when omitted — with `TomRequestIdPolicy.configure`: the request-id header and the proxies it is believed from. Without the key nothing changes, so `X-Request-Id` is echoed and believed from no one and every request runs under its trace id. Throws a `TomRequestIdException` keyed `server.request_ids.config.invalid` for a value of the wrong shape, before anything is applied. Called by `start`, right after `configureHttpClients`. See [server.md](../server.md#request-ids). |
| `configureIdempotency` | `static void configureIdempotency([TomServerConfigResourceProvider? config])` | Applies the `idempotencyConfigurationKey` map of `config` — the server configuration when omitted — with `TomIdempotency.configure`: a `datasource` installs a `TomSqlIdempotencyStore` over the data source of that name (`table`, `createSchema`), `retentionMinutes` sets `TomIdempotency.defaultRetention`, `inProgressTimeoutSeconds` sets `TomIdempotency.inProgressTimeout`. Without the key nothing changes, and the in-memory store with a 24-hour retention stands — which holds on one process only. Throws a `TomIdempotencyException` keyed `endpoint.idempotency.config.invalid` when the value is not a map or a duration is not a positive whole number, before anything is applied. Called by `start`. See [configuration.md](../configuration.md#idempotency-keys). |
| `configureFieldEncryption` | `static Future<void> configureFieldEncryption([TomServerConfigResourceProvider? config])` | Applies the `TomFieldEncryption.configurationKey` (`fieldEncryption`) map of `config` — the server configuration when omitted — with `TomFieldEncryption.configure`: installs a `TomFieldKeyring` over a `TomSqlDataKeyStore` of the named data source (`table`, `createSchema`) with the listed key-encryption keys (`keys`, primary first), `refreshSeconds` and `acceptPlaintext`, and loads its keys. Without the key nothing is installed, and an encrypted column fails its first write with `field_encryption.not_configured` rather than storing plaintext. Throws a `TomFieldEncryptionException` keyed `field_encryption.config.invalid` for a value of the wrong shape and `field_encryption.invalid_kek` for a bad key, before anything is installed. A `secret:` reference in a key is resolved by `TomFieldEncryption.configure` through the registered secrets providers. Called by `start`, after `configureIdempotency`. See [configuration.md](../configuration.md#field-level-encryption). |
| `configurePrivacy` | `static void configurePrivacy([TomServerConfigResourceProvider? config])` | Applies the `TomPrivacy.configurationKey` (`privacy`) map of `config` — the server configuration when omitted — with `TomPrivacy.configure`: installs `TomSubjectKeys` over a `TomSqlSubjectKeyStore` of the named data source (`table`, `createSchema`), wrapped under the installed field-encryption keyring's key-encryption keys, which makes the audit trail seal `@TomPersonal` values per data subject so an erasure reaches them there. Without the key nothing is installed and personal values are recorded as they are. Throws a `TomPrivacyException` keyed `privacy.config.invalid` for a value of the wrong shape. Called by `start`, after `configureFieldEncryption`, whose keys wrap the subject keys. See [configuration.md](../configuration.md#privacy). |
| `recoverTransactions` | `static Future<TomRecoveryReport?> recoverTransactions([TomServerConfigResourceProvider? config])` | Applies the `TomTransactionRecovery.configurationKey` (`transactions`) map of `config` — the server configuration when omitted — with `TomTransactionRecovery.configure`, which installs a `TomSqlDecisionLog` as `TomTransactionManager.decisionLog` when `decisionLog` names a data source; with `recoverOnStart` it then runs `TomTransactionRecovery.recover()` over every registered two-phase data source, logs the report and returns it. Returns `null` when there is no key or no recovery ran. Throws a `TomTransactionRecoveryException` keyed `transactions.recovery.config.invalid` for a value of the wrong shape. Called by `start`, after `configurePrivacy` and before the deployment's own login, so the prepared branches are resolved before a request can meet their locks. See [configuration.md](../configuration.md#transaction-recovery). |
| `applyLogFormat` | `static bool applyLogFormat(String format)` | Applies a `logFormat` setting and answers whether it was recognised. `json` replaces the default console output (`TomConsoleLogOutput`) with a kernel `TomJsonLogOutput` — one JSON object per line carrying `trace_id`, `span_id`, `request_id` and `tenant` — and keeps an output the application installed itself; `text` or empty changes nothing; any other value is logged as an error, changes nothing and answers `false`. Called by `start`; public and static so a boot step that logs before the server starts can apply the same setting earlier. |

### TomEndpointCredentials

The paths whose `Authorization` header belongs to the endpoint, not to the
framework. Some callers present a credential that is not a token of this
deployment — an identity provider calling the SCIM endpoints presents the
static bearer secret it was configured with. Read by `extractAuthentication`,
such a header would be verified as a JWT, refused, and logged as a refused
credential on every call; for a claimed path it is skipped instead, the request
proceeds with no principal, and the endpoint checks the header itself. Claim a
prefix only for endpoints that do check it — a claimed path is unauthenticated
as far as the framework knows. `TomScimProvisioning.install` claims
`/scim/v2/`.

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `claim` | `static void claim(String pathPrefix)` | Claims every path that starts with `pathPrefix`. |
| `release` | `static void release(String pathPrefix)` | Withdraws the claim on `pathPrefix`. |
| `claims` | `static bool claims(Request request)` | Whether `request`'s path starts with a claimed prefix. |

### TomGracefulShutdown

The graceful shutdown of one server: what it does between SIGTERM and exiting.
`shutdown` runs six steps in order — readiness off
(`TomHealthServer.markShuttingDown`), the readiness delay, the listener closed
so no new connection is accepted, every started scheduler (`TomScheduler.started`,
the outbox's included) stopped while the requests and runs in flight get until
the deadline to finish, the started outboxes (`TomMessageOutbox.started`) and
schedulers closed once the answered requests' responses are written — releasing
their leases — with the connections still open at the deadline closed, and the
data sources' pools closed (`TomDataSourceInfo.closeAll`). A closing step that
fails is logged as a warning and the next one runs. `TomServer.start` registers
it as a `tomShutdownCleanup` signal handler, so it runs before the closables and
disposables registered there.

#### Constructors

```dart
TomGracefulShutdown({
  Duration gracePeriod = const Duration(seconds: 20),
  Duration readinessDelay = Duration.zero,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `gracePeriod` | `Duration` | How long requests in flight and running scheduled work may take to finish once the listener is closed. One deadline shared by requests, runs and connections. |
| `readinessDelay` | `Duration` | How long requests are still accepted after readiness turned to `503`, so a load balancer that has not yet noticed sends nothing into a closed socket. |
| `httpServer` | `HttpServer?` | The bound socket, set by `TomServer.start`. Closed when the shutdown stops accepting, and force-closed at its end; while it is set, the shutdown also waits for its open connections to close, which is when the last response has been written. `null` leaves the socket out of the shutdown. |
| `inFlight` | `int get` | How many requests are being served right now, counted by `middleware`. |
| `isDraining` | `bool get` | Whether the listener has closed and new requests are refused. |
| `isShuttingDown` | `bool get` | Whether `shutdown` has been started. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `middleware` | `Middleware middleware()` | Counts the requests in flight and, while draining, answers every request but the probe paths (`tomProbePaths`) with `503 shutting down`, `Connection: close` and `Retry-After: 1`, which a client or proxy retries elsewhere. `TomServer.start` installs it as the outermost layer of the pipeline. |
| `shutdown` | `Future<void> shutdown()` | Runs the shutdown once; a second call is handed the first one's future. Completes when the pools are closed. What is unfinished at the deadline is logged as a warning and not waited for. |

### TomRequestIdPolicy

How a request's id is chosen. A request carrying `header` **from one of the
`trustedProxies`**, with a value the kernel's `TomRequestId.isValid` accepts,
runs under that value; otherwise it runs under the id of its trace — the
caller's trace id when its `traceparent` is valid, so caller and server log one
id for one piece of work, or the id of the new trace it starts. A malformed
header of either kind is ignored, never refused. A trace id is accepted from
anyone: it carries no authority, and its format leaves nothing to inject.

- **Kind:** final class.
- **Extends:** none

#### Constructors

```dart
const TomRequestIdPolicy({
  String header = tomRequestIdHeader,
  Set<String> trustedProxies = const {},
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `header` | `String` | The request-id header: echoed on every response, and believed from a trusted proxy (final). |
| `trustedProxies` | `Set<String>` | The addresses of the proxies whose request-id header is believed — the socket peer, compared as its address text (`10.0.0.2`, `::1`) (final). |

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `configurationKey` | `String` | `'requestIds'`, the configuration key `configure` reads (const). |
| `current` | `TomRequestIdPolicy` | The policy the request pipeline applies; set by `configure`. Defaults to `const TomRequestIdPolicy()`: `X-Request-Id`, believed from no one. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `configure` | `static void configure(Object? config)` | Sets `current` from the `requestIds` map — `header` (optional, default `X-Request-Id`; letters, digits and `-`) and `trustedProxies` (optional, a list of IP addresses; none by default). Throws `server.request_ids.config.invalid` for a value that is not a map, an unknown key, a `header` that is not a header name or an entry that is not an IP address, before anything is applied. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `resolve` | `TomRequestId resolve(Request request, TomTraceContext trace)` | The id `request` runs under, given the `trace` it is served in: the trimmed `header` value when the socket peer (`TomClientAddress.connectionInfoKey`) is one of `trustedProxies` and `TomRequestId.tryOf` accepts it, else `TomRequestId.of(trace.traceId)`. |

### TomRequestIdException

Thrown when the request-id settings cannot be applied.

| Key | Meaning |
| --- | ------- |
| `server.request_ids.config.invalid` | The `requestIds` configuration has a value of the wrong shape; thrown by `TomRequestIdPolicy.configure`. |

- **Extends:** `TomServerException`

#### Constructors

```dart
TomRequestIdException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool autoLog = false,
})
```

## Enums

### TomCredentialOutcome

Why a request carries the credentials it does — the third element of
`extractAuthentication`'s result. A `null` principal and a `null` token is the
answer to five different requests: an anonymous caller, a misconfigured client,
a signing key rotated past an issuer, a malformed claim set, and a credential
that belongs to the endpoint. Those call for five different actions, and the
first two elements cannot tell them apart.

The distinction is for the reader of the function, not for the HTTP client —
the four refusals still receive the same answer over the wire, because a client able to
tell "your signature was wrong" from "you sent nothing" is an attacker able to
tell whether they guessed.

`extractAuthentication` reads the `Authorization` header only. A request it
reports as `noCredentials` may still carry a service account's `X-API-Key`,
which `tomDefaultAuthenticationMiddleware` reads afterwards through the
installed `TomApiKeys`.

| Value | Meaning |
| ----- | ------- |
| `noCredentials` | No `Authorization` header. An ordinary anonymous caller. |
| `unsupportedScheme` | The header named a scheme other than `Bearer`, or none at all. Nothing was read from it. |
| `unreadableToken` | A bearer token `verifyBearerToken` refused: a wrong signature, a key this deployment cannot check against, a body that would not decode, or an empty one. |
| `noPrincipal` | The token verified but yielded no principal — ordinarily because it is not live (expired, without a readable `exp`, or with a `validUntil` that disagrees with its `exp`), which `TomBearerAuthentication.convertTokenPayloadToPrincipal` refuses. The token is handed back with the outcome, so a refresh endpoint is reached with exactly it. |
| `authenticated` | The token verified and yielded a principal. |
| `endpointCredential` | The request's path belongs to an endpoint that authenticates its callers itself (`TomEndpointCredentials`); the header was left for it, unread. |

## Global Functions and Constants

| Name | Signature | Description |
| ---- | --------- | ----------- |
| `contextSetupMiddleware` | `Middleware contextSetupMiddleware(String id, [Map<String, Object>? context])` | A pass-through shelf `Middleware` that merges `context` into a copy of the request context before the inner handler runs (`id` labels it for tracing). The entries are the same objects for every request, so a value a request mutates — a `TomRequestLogInfo` — is seeded by `tomRequestLogInfoMiddleware` instead. |
| `tomRequestLogInfoMiddleware` | `Middleware tomRequestLogInfoMiddleware()` | Seeds a new `TomRequestLogInfo` under `TomRequestLogInfo.contextName` into every request's context — one instance per request, because `tomLoggingMiddleware` marks it logged and the endpoint pipeline sets whether it should be. `TomServer.start` installs it directly inside the shutdown gate (`TomGracefulShutdown.middleware`). |
| `tomRequestIdHeader` | `const String tomRequestIdHeader = 'X-Request-Id'` | The default request-id header: the one a server echoes the request id in, so a caller can quote it to support, and the one it believes from a trusted proxy. |
| `tomRequestContextMiddleware` | `Middleware tomRequestContextMiddleware({TomRequestIdPolicy? policy})` | Gives every request its correlation ids before anything else runs: the W3C trace context its `traceparent` header continues — a child span of the caller's trace, its valid `tracestate` kept, or a new trace (`TomTraceContext.newRoot`) when the header is missing or invalid — and the `TomRequestId` that `policy` (by default `TomRequestIdPolicy.current`, read per request) chooses: a trusted proxy's id, else the trace id. Runs the rest of the pipeline in a zone carrying both, so the access-log line, an error logged during authentication and every line a handler writes share the same `request_id`, `trace_id` and `span_id`. Answers with the request id in the policy's header and the server span as `traceparent`. `TomServer.start` installs it after the metrics endpoint and before the request metrics. |
| `extractAuthentication` | `(TomPrincipal?, TomClientJwtToken?, TomCredentialOutcome) extractAuthentication(Request req)` | Extracts bearer credentials from the `Authorization` header, returning `(principal, token, outcome)`. A header on a path claimed in `TomEndpointCredentials` is not read: the answer is `(null, null, endpointCredential)`. The first two elements are `null` whenever the request is not authenticated; [`TomCredentialOutcome`](#tomcredentialoutcome) says which of the five ways that happened, because `(null, null)` is the answer to all five and an operator cannot act on it. Never raises and never refuses — a public endpoint is served through this same pipeline — but every refusal is recorded at warning level, and never with the credential in it. The scheme is matched case-insensitively, as RFC 7235 requires. |
| `tomDefaultAuthenticationMiddleware` | `Middleware tomDefaultAuthenticationMiddleware(String id, [Map<String, Object>? context])` | The default authentication middleware: resolves the effective `TomPrincipal` — from the bearer token, or, when the request carries no `Authorization` header, from an `X-API-Key` the installed `TomApiKeys` accepts (ignored with a warning when none is installed) — and runs the inner handler in a zone exposing the request, execution context, principal, token, the `TomApiKeyIdentity` of an accepted key, and the `TomRequestId` — the one `tomRequestContextMiddleware` set when it ran outside, a new random one otherwise — and inside a `TomTransactionManager.runInTransactionScope`, so the current transaction is per-request rather than per-isolate. A replacement must establish both. |
| `tomLoggingMiddleware` | `Middleware tomLoggingMiddleware()` | The default request-logging middleware: emits one access-log line per request, guarded by the request's `TomRequestLogInfo`. Both guards are the reason shelf's `logRequests()` is not the default — it reads no request context, so it can honour neither. |
| `noopHandler` | `Handler noopHandler(String id, int statusCode)` | A `Handler` that ignores the request and always replies with `statusCode` (`id` labels it for tracing). |
| `tomProbePaths` | `const Set<String> tomProbePaths = {'health', 'ready'}` | The paths a draining server keeps answering — the liveness and readiness probes — so an orchestrator sees an alive, unready process rather than a dead one. `TomGracefulShutdown.middleware` passes them through while it refuses everything else. |
