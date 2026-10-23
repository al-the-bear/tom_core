# Server Module

The HTTP entry point of a Tom server application. `TomServer` takes a
`TomBaseServerConfiguration`, assembles a [shelf](https://pub.dev/packages/shelf)
middleware pipeline in front of the endpoint router, and binds it to a socket.
The module also provides the middleware that the pipeline is built from —
context setup, authentication, error mapping, and request logging — plus
`TomRequestLogInfo`, the per-request logging state that travels in the request
context. The other per-request value object, the correlation id `TomRequestId`,
is *produced* here — the request-context middleware mints one for every request,
together with the request's W3C trace context — but declared in the little-things module, beside the exception
base that reads it; see [little_things.md](little_things.md#tomrequestid).

## Table of Contents

- [Overview](#overview)
- [Starting a Server](#starting-a-server)
  - [The Deployment Logs Itself In First](#the-deployment-logs-itself-in-first)
- [The Pipeline](#the-pipeline)
- [Correlation Ids and Structured Logs](#correlation-ids-and-structured-logs)
  - [The log format](#the-log-format)
- [Request Context and Zone Values](#request-context-and-zone-values)
  - [Endpoint-owned credentials](#endpoint-owned-credentials)
  - [A service account's API key](#a-service-accounts-api-key)
  - [The request's tenant](#the-requests-tenant)
- [Error Mapping](#error-mapping)
- [Extending the Pipeline](#extending-the-pipeline)
- [Metrics](#metrics)
- [Graceful Shutdown](#graceful-shutdown)
  - [What it waits for](#what-it-waits-for)
  - [Configuration](#configuration)
  - [Kubernetes](#kubernetes)
- [Verification](#verification)
- [Not Yet Implemented](#not-yet-implemented)
  - [What this module does not do at all](#what-this-module-does-not-do-at-all)
- [Dependencies](#dependencies)

---

## Overview

| Symbol | Kind | Purpose |
| ------ | ---- | ------- |
| `TomServer` | class | Composes the pipeline and binds the socket |
| `TomGracefulShutdown` | class | What the server does between SIGTERM and exiting: readiness off, new requests refused, work in flight finished, leases released, pools closed |
| `tomProbePaths` | const Set<String> | `health` and `ready`, the paths a draining server keeps answering |
| `TomRequestLogInfo` | class | Per-request logging state in the request context |
| `TomCredentialOutcome` | enum | Why a request carries the credentials it does |
| `TomEndpointCredentials` | abstract final class | The path prefixes whose `Authorization` header belongs to the endpoint, which `extractAuthentication` leaves unread. Statics only |
| `contextSetupMiddleware` | function | Seeds entries into the request context — the same objects for every request |
| `tomRequestLogInfoMiddleware` | function | Seeds a new `TomRequestLogInfo` into every request's context |
| `tomRequestContextMiddleware` | function | Mints the request id and continues or starts the W3C trace; answers with both |
| `tomRequestIdHeader` | const String | `X-Request-Id`, the response header carrying the request id |
| `tomDefaultAuthenticationMiddleware` | function | Extracts credentials and publishes request zone values |
| `tomLoggingMiddleware` | function | Emits the one-shot access-log line, prefixed with the application id |
| `extractAuthentication` | function | Reads bearer credentials from a request |
| `noopHandler` | function | A handler that always returns a fixed status code |

## Starting a Server

```dart
final server = TomServer(configuration);   // a TomBaseServerConfiguration
final socket = await server.start();       // completes when it is listening
```

`TomServer` reads everything it needs from the configuration: the service
credential (below), TLS material (`certificateChain` / `privateKey`, unless
`noSsl`), the listen address (`host`, or any-IPv4 when empty or
`listenToAnyIp`), the `port`, `isolateCount` (sockets are `shared` when more
than one), `autoCompress`, the `serverHeader` / `poweredByHeader`,
`openApiDocument`, the generated OpenAPI document `GET /openapi.json` serves
(see [endpoints.md](endpoints.md#the-openapi-document)), `logFormat`, the shape
of every log line (see [The log format](#the-log-format)), and
`frameworkReadiness`, which answers `GET /ready` with the framework's own
readiness checks unless the application installed a readiness analyzer of its
own (see [healthcheck.md](healthcheck.md#the-framework-readiness-checks)).
First of all, before the deployment's own login, `start()` applies the
`httpClient` key of the configuration resources (`TomServer.configureHttpClients`): the timeout, retry,
circuit-breaker and bulkhead policies every outgoing framework call runs under,
for all destinations and for named ones. A value of the wrong shape stops the
start with `http.client.config.invalid`; without the key the kernel's defaults
stand, a 30-second timeout among them (see
[configuration.md](configuration.md#outgoing-http-calls)). Right after, it
applies the `idempotency` key (`TomServer.configureIdempotency`): the store the
`@TomIdempotent` endpoints keep their keys in and how long a response is
replayed. A value of the wrong shape stops the start with
`endpoint.idempotency.config.invalid`; without the key the keys are kept in
memory, on one process (see
[configuration.md](configuration.md#idempotency-keys)). Then it awaits the
`fieldEncryption` key (`TomServer.configureFieldEncryption`): the data-key table
and the key-encryption keys `@TomEncrypted` columns are encrypted under, from
which it installs the keyring and loads its keys — before the deployment's own
login and before anything reads an entity. A value of the wrong shape stops the
start with `field_encryption.config.invalid`, a key that is not 32 bytes of
base64 with `field_encryption.invalid_kek`; without the key no keyring is
installed, and an encrypted column fails its first write with
`field_encryption.not_configured` (see
[configuration.md](configuration.md#field-level-encryption) and
[object_persistence.md](object_persistence.md#field-level-encryption)). Right
after, it applies the `privacy` key (`TomServer.configurePrivacy`): the table of
the subject keys the audit trail seals personal values under, wrapped under the
keyring's key-encryption keys — which is why it comes after them. A value of the
wrong shape stops the start with `privacy.config.invalid`; without the key no
subject keys are installed, and personal values are recorded in the trail as
they are (see [configuration.md](configuration.md#privacy) and
[privacy.md](privacy.md#crypto-shredding-in-the-audit-trail)). Then it awaits
the `transactions` key (`TomServer.recoverTransactions`): the one-phase data
source two-phase commit decisions are recorded in, and whether to recover. With
`recoverOnStart` it resolves the two-phase branches a dead process left
prepared — committing those a recorded decision names, rolling back the rest —
before the server takes a request that could meet their locks, and logs the
report. A value of the wrong shape stops the start with
`transactions.recovery.config.invalid`; without the key no decision is recorded
and nothing is recovered (see
[configuration.md](configuration.md#transaction-recovery) and
[transactions.md](transactions.md#recovering-prepared-branches)).
`start()` completes **when the socket is listening**, with the bound
`HttpServer`. So a bind failure — a port already in use, an unreadable
certificate, a malformed private key — rejects the returned future instead of
surfacing as an unhandled asynchronous error; a caller can tell *listening* from
*called*, which is what a test or a supervisor needs before it sends the first
request; and the socket can be closed by whoever opened it.

Once the socket is bound, `start()` hands it to the server's graceful shutdown
and registers that with the kernel's `tomShutdownCleanup` for SIGTERM and
SIGINT, so a signal stops the server in order rather than mid-request — see
[Graceful Shutdown](#graceful-shutdown).

Awaiting is optional. A caller that ignores the future gets the fire-and-forget
behaviour a `void` return used to give, because the bound socket keeps the
isolate alive on its own — which is why the sample servers' `main` still ends on
this call. What changed is that ignoring it is a choice.

### The Deployment Logs Itself In First

Before any of that, `start()` calls `TomServerSelfLogin.loginAndInstall` against
the configuration, so the deployment holds its own `TomServerPrincipal` by the
time it accepts a request.

The ordering is load-bearing rather than tidy: the server principal caps every
user's grants at `min(user, server)`, so binding the socket first would open a
window in which requests were served *uncapped* — the one direction in which
getting this wrong grants access rather than denying it.

There are three outcomes, and only the middle one is new to a deployment:

- **No service credential configured** — the default. The login is skipped, an
  info line records the skip, no server principal is installed, and access
  evaluation is the user's grant alone. Nothing about such a server changes.
- **Configured and the login fails** — the error is logged and **rethrown, and
  the socket is never bound**: `start()`'s future rejects with it, under the log
  line `Server self-login failed — refusing to bind the socket`. Starting anyway
  would mean running uncapped after explicitly asking to be capped, so this
  aborts rather than degrades.
- **Configured and the login succeeds** — the principal is installed and user
  grants are capped from the first request onward.

The credential is configuration surface owned by the authentication module —
`authServerLoginUri`, `serviceAccountName`, `serviceAccountCredential` and the
tenant coordinates; all three of the first are required, and a blank one means
"not configured". See [authentication.md](authentication.md) for the credential
and the login flow itself.

## The Pipeline

`start()` composes a shelf `Pipeline` in front of the endpoint `Router`, in this
order:

1. **Shutdown gate** — `TomServer.gracefulShutdown.middleware()`, the outermost
   layer: it counts the requests in flight, which is what the shutdown waits
   for, and once the shutdown is draining answers every new request `503` with
   `Connection: close` and `Retry-After: 1`, before anything below sees it. The
   probe paths (`tomProbePaths`) are passed through. Outermost, so every
   request the server does any work for is counted — a metrics scrape included
   — and a refused one costs nothing below: it is not logged, counted in the
   request metrics or authenticated. See [Graceful Shutdown](#graceful-shutdown).
2. **`tomRequestLogInfoMiddleware`** — seeds a new `TomRequestLogInfo` into
   each request's context under `TomRequestLogInfo.contextName`. One instance
   per request, because the record is mutated per request: the logging
   middleware marks it logged and the endpoint pipeline sets whether it should
   be. `contextSetupMiddleware` is not used for it — the entries it seeds are
   the same objects for every request.
3. **Metrics endpoint** — `tomMetricsEndpointMiddleware`, present when the
   `metricsEndpoint` configuration key is on: answers a Prometheus scrape of
   `metricsPath` (default `/metrics`), checking the `metricsToken` bearer token
   when one is set, and passes every other request on. A scrape is answered
   here, before anything below sees it — it is infrastructure like a probe, so
   it is not counted, logged, authenticated or rate-limited. See
   [metrics.md](metrics.md).
4. **Request context** — `tomRequestContextMiddleware`, which mints the
   request's `TomRequestId`, continues the caller's W3C trace from its
   `traceparent` header (or starts one), and runs everything below in a zone
   carrying both. Its place is what makes the ids complete: it is outside the
   access log, both error layers and authentication, so every line any of them
   writes for the request carries the same `request_id`, `trace_id` and
   `span_id`. A metrics scrape is answered above it and gets no ids. See
   [Correlation Ids and Structured Logs](#correlation-ids-and-structured-logs).
5. **Request metrics** — `tomRequestMetricsMiddleware`, recording
   `tom_http_server_requests` and `tom_http_server_request_duration_seconds`
   for every request, labelled by the route pattern the endpoint pipeline
   writes into `TomRequestLogInfo.route` (`unmatched` when no endpoint matched,
   which includes a request refused before routing). It sits outside both error
   layers, so a request is counted with the status the client received.
6. **Logging middleware** — `loggingMiddleware` (defaults to
   `tomLoggingMiddleware`), which emits one line per served request:

   ```text
   [billing] HTTP/1.1 [GET] /tasks http://localhost:8080/tasks 200 null
   ```

   The leading `[billing]` is `tomAppId` — the `appId` of the configuration this
   isolate built (see `doc/configuration.md`). It is what tells the access logs
   of a deployment's several servers apart once they are collected in one place;
   the requested URI carries a port, but that only separates them while they are
   separate ports on one host. A deployment that configures no `appId` sees the
   line without the prefix.
7. **Outer error handler** — catches errors from the authentication phase using
   the `authenticationErrorHandler`.
8. **Authentication middleware** — the configuration's `authenticationMiddleware`
   or `tomDefaultAuthenticationMiddleware`.
9. **Rate-limiting middleware** — `tomRateLimitMiddleware()`, directly inside
   authentication, where the request's principal and the API key it
   authenticated with are in the zone. A no-op while no limits are installed;
   otherwise a request over a limit is answered `429` here, before any handler
   runs. `start()` installs the limits the `rateLimits` configuration key
   describes when no limits were installed before it. See
   [ratelimit.md](ratelimit.md).
10. **Inner error handler** — catches errors from handling using `errorHandler`.
11. **Router** — optionally wrapped in a `Cascade` with the configuration's
    `preExecutionHandler` / `postExecutionHandler`.

**Logging sits above both error layers**, and that is what makes the access log
complete. A request that fails while its principal is being established — an
expired token, a token signed by the wrong key, an authorization cache that
cannot be reached — has been turned into a response by the error layer *below*
the logging middleware, so it is logged like any other request. Below them it
could not be: the error layer answers the request, and nothing further in runs,
so the traffic most worth reading about produced no line at all.

It logs a response, not an outcome. The one case still absent is an error that
escapes *both* layers, where no response was produced and there is no status to
write; `_handleError` logs that error itself and shelf answers the client.
The endpoint pipeline's own richer line still wins for a served request — it
marks `hasBeenLogged`, so moving the middleware outwards adds no second line.

## Correlation Ids and Structured Logs

Every request gets two correlation ids before any other part of the pipeline
sees it, from `tomRequestContextMiddleware`:

| Id | Where it comes from | Where it goes |
| -- | ------------------- | ------------- |
| `TomRequestId` | Minted per request — a v4 UUID | The request zone; the `X-Request-Id` response header (`tomRequestIdHeader`); the `request_id` field of every structured log line; a `TomServerException`'s `requestUuid`; the audit trail's `requestId` |
| W3C trace context (`TomTraceContext`, kernel) | The request's `traceparent` header, continued with a child span of this server's own; a new trace when the header is missing or does not parse | The request zone; the `traceparent` response header (the server span); the `trace_id` and `span_id` fields of every structured log line |

The request id is what a user quotes to support; the trace id is what joins
this server's lines to those of the caller and of every service it calls. A
caller-supplied `X-Request-Id` is not adopted — the id is the server's — while a
caller's `traceparent` is continued, because joining traces across services is
what the header is for.

`tomDefaultAuthenticationMiddleware` carries the request id it finds in the
zone into the request's `TomZoneValues` rather than minting a second one, so the
id on the response header, on a server exception and in the audit trail is the
same id. Used on its own — without the request-context middleware outside it —
it mints one itself.

Building the middleware registers the `request_id` field with the kernel's
`TomLogContext`; the kernel registers `trace_id`, `span_id` and `tenant`. Those
fields are read from the zone each line is logged in, so a handler logs as it
always did and the line carries them without being passed anything.

### The log format

`logFormat` decides how every log line is written:

| Value | Output |
| ----- | ------ |
| `text` (default) | One human-readable line per entry — the default console output stays installed |
| `json` | One JSON object per line (kernel `TomJsonLogOutput`): `timestamp`, `level`, `message`, `logger`, `isolate`, then the context fields `trace_id`, `span_id`, `tenant` and `request_id` where the zone has them |

```text
{"timestamp":"2026-10-20T08:15:02.113Z","level":"info","message":"…","logger":"TasksServer.list","isolate":"main","trace_id":"4bf92f3577b34da6a3ce929d0e0e4736","span_id":"b7ad6b7169203331","tenant":"acme","request_id":"0f4c…"}
```

Use `json` wherever a log collector indexes the lines: "every line of one
request" or "every error of one tenant" is then a field query rather than a
regular expression over free text. **No fixed field and no framework context
field carries personal data** — they are ids of a trace, a span, a request and a
tenant, never a user name, an address or a principal — so every line may be
kept wherever the logs are kept. What a message says is still the message's
business.

`start()` applies the setting through `TomServer.applyLogFormat`, which replaces
only the default console output: an application that installed an output of its
own keeps it. An unrecognised value is logged as an error and changes nothing.
A boot step that logs before the server starts can call
`TomServer.applyLogFormat(configuration.logFormat)` itself, earlier.

## Request Context and Zone Values

Three channels carry per-request state:

- **The shelf request context** holds `TomRequestLogInfo` (keyed by
  `TomRequestLogInfo.contextName`). Set its `shouldBeLogged` to `false` to
  suppress the access-log line for a request (e.g. health checks); the logging
  middleware also flips `hasBeenLogged` so the line is emitted at most once.
- **The request `Zone`** (established by `tomDefaultAuthenticationMiddleware`)
  exposes a `TomZoneValues` bundle: the shelf `Request`, the ambient
  `TomExecutionContext`, the resolved `TomPrincipal`, the `TomClientJwtToken`,
  the `TomApiKeyIdentity` of a request a service account's API key
  authenticated (`null` otherwise; see
  [API keys](#a-service-accounts-api-key)), and the `TomRequestId`
  `tomRequestContextMiddleware` minted (declared in the little-things module) — and, in a
  multi-tenant deployment, the request's tenant (see
  [The request's tenant](#the-requests-tenant)). Downstream
  code recovers any of them with
  `getFromCurrentZone<T>()` — this is how the endpoints pipeline and
  `TomServerException` obtain the request id and principal.
- **The current transaction.** The same middleware wraps that whole zone in
  `TomTransactionManager.runInTransactionScope`, so the transaction every
  repository call finds as "current" belongs to the one request rather than to
  the isolate. Without the scope, two requests interleaving in one isolate share
  whatever the manager considers current — either can see, commit or roll back
  the other's work — and `isolateCount > 1` does not help, because the sharing
  is *within* an isolate. See `doc/transactions.md` for the manager itself.

`extractAuthentication` is the credential reader: it parses a `Bearer <jwt>`
`Authorization` header into a `(TomPrincipal?, TomClientJwtToken?,
TomCredentialOutcome)` record. The first two elements are `null` whenever the
request is not authenticated — an invalid token is treated as "no credentials",
not an error, because an endpoint marked `@TomPublicAccess()` is served through
this same pipeline. The scheme is matched case-insensitively, as RFC 7235
requires.

`TomCredentialOutcome` is the third element, and it exists because the first two
cannot say what happened. `(null, null)` is the answer to five different
requests:

| Outcome | The request |
| ------- | ----------- |
| `noCredentials` | Sent no `Authorization` header. An ordinary anonymous caller. |
| `unsupportedScheme` | Sent a scheme other than `Bearer`, or a header with no scheme at all. |
| `unreadableToken` | Sent a bearer token `verifyBearerToken` refused — a wrong signature, a key this deployment cannot check against, a body that would not decode, or an empty one. |
| `noPrincipal` | Sent a token that verified but yielded no principal. The ordinary cause is a token that is not live — expired, without a readable `exp`, or with a `validUntil` that disagrees with its `exp` — which `TomBearerAuthentication.convertTokenPayloadToPrincipal` refuses. The token is handed back with the outcome, so a refresh endpoint is reached with exactly it. |
| `authenticated` | Sent a token that verified and yielded a principal. |
| `endpointCredential` | Sent a header to a path claimed in `TomEndpointCredentials`. The header was left for the endpoint, unread — see [Endpoint-owned credentials](#endpoint-owned-credentials). |

A request that sent no `Authorization` header (`noCredentials`) may still carry
a service account's `X-API-Key`, which `tomDefaultAuthenticationMiddleware`
reads after the outcome is known — see
[A service account's API key](#a-service-accounts-api-key).

An anonymous caller and a client whose signing key this deployment stopped
recognising are the two worth separating. Rotate a key, miss an issuer, and
every affected client silently becomes anonymous: the server sees anonymous
traffic and the authorization layer answers `401`, and without the outcome
nothing anywhere says a token arrived and could not be read.

Every refusal is also written to the log at warning level — `unsupportedScheme`
by `extractAuthentication`, `unreadableToken` by `verifyBearerToken` — and never
with the credential in it. A header is named by its *scheme*, and one with no
scheme is reported as having none rather than by quoting what the client sent in
its place; a refused token is named by the decoder's reason and not by its text.
A token this server cannot read is very often a live credential somewhere else,
and an access log is the least protected place it could end up.

The principal the zone finally carries is resolved from those two: a principal
`TomAuthorizationCache` holds for the token wins, a cache miss falls back to the
one `extractAuthentication` decoded, and an entry the cache reports as **expired**
resolves to no principal at all — the same answer an uncredentialed request
gets. The middleware itself never refuses; a protected endpoint refuses the
request downstream, and a refresh or re-login endpoint stays reachable with the
token still in the zone. See
[authorization.md](authorization.md#an-expired-entry-resolves-to-no-principal)
for why the token-derived principal is not used as the fallback there.

### Endpoint-owned credentials

Some callers present a credential that is not a token of this deployment. An
identity provider calling the SCIM endpoints presents the static bearer secret
it was configured with; read by `extractAuthentication`, that header would be
verified as a JWT, refused as `unreadableToken`, and logged as a refused
credential on every call. `TomEndpointCredentials` names the paths whose header
belongs to the endpoint instead:

| Member | Effect |
| ------ | ------ |
| `claim(String pathPrefix)` | Claims every path that starts with `pathPrefix` |
| `release(String pathPrefix)` | Withdraws the claim |
| `claims(Request request)` | Whether the request's path is claimed |

For a claimed path that carries an `Authorization` header,
`extractAuthentication` answers `(null, null, endpointCredential)` without
reading the header: the request proceeds with no principal, and the endpoint
checks the header itself. A request with no header is still `noCredentials`.
`TomScimProvisioning.install` claims `/scim/v2/` and `reset` releases it (see
[authentication.md](authentication.md#enabling-scim)).

Claim a prefix only for endpoints that do check the header — a claimed path is
unauthenticated as far as the framework knows, so an endpoint under it that
relies on the framework's principal sees none.

### A service account's API key

When the request carries **no `Authorization` header** and an `X-API-Key`,
`tomDefaultAuthenticationMiddleware` hands the key to the installed `TomApiKeys`
(see [authentication.md](authentication.md#service-accounts-and-api-keys)). An
accepted key puts the service account's principal in the zone as a bearer token
would, and its `TomApiKeyIdentity` beside it. A key that authenticates nothing
leaves the request unauthenticated, and `TomApiKeys.authenticate` logs the
reason without the key.

The header is read only when no `Authorization` header was sent: a request
presenting both is answered as the bearer it presented, so a key never widens
what a signed-in user may do. A server with no `TomApiKeys` installed ignores
the header with a warning. A substitute authentication middleware that should
admit service accounts has to read the key the same way.

### The request's tenant

When a `TomTenancy` is installed (see [tenancy.md](tenancy.md)),
`tomDefaultAuthenticationMiddleware` resolves every request's tenant before any
handler runs, through `TomTenancy.resolveRequest`:

1. the verified token's `tenant` claim, when the request carries one, is
   authoritative;
2. otherwise the configured resolvers — host, then header — are asked in order;
3. no answer at all is not a refusal: the request runs explicitly outside every
   tenant, and tenant-owned data is closed to it.

The request then runs inside `TomTenantContext.run(tenant, …)`, which wraps the
transaction scope and the zone values above, so everything it reaches — the
repositories, the caches, the outbox — reads the tenant from the zone. A refused
request is answered by the middleware itself, with a small JSON body
`{"error": <key>, "message": <message>}` and `Content-Type: application/json`:

| Status | Key | When |
| ------ | --- | ---- |
| `403` | `tenancy.resolution.conflict` | The host or a header names another tenant than the token — a token is not a pass to another tenant |
| `404` | `tenancy.tenant.unknown` | The request names a tenant the deployment does not have |
| `400` | `tenancy.id.invalid` | The request names something that is not a tenant id |

With no tenancy installed the middleware resolves no tenant and adds no tenant
zone. A substitute authentication middleware that serves a
multi-tenant deployment has to establish the tenant the same way.

## Error Mapping

`TomServer.errorHandler` turns a thrown error into an HTTP 500 JSON response
carrying the `x-tom-error: true` header and
`Content-Type: application/json;charset=UTF-8`. Provide
`TomBaseServerConfiguration.errorHandler` / `authenticationErrorHandler` to
override the mapping.

The body is `tomErrorEnvelope` — the package's single definition of the wire
error shape, which this handler *renders* and does not define. It always
includes `errorType`; a `TomException` additionally contributes `errorKey`,
`uuid`, `autoLog` and `requestUuid`; and a `TomServerException` adds
`clientThrow`. The builder lives in `little_things`, beside the exception base
that decides that last field; see [little_things.md](little_things.md#the-error-envelope)
for what each field means and why one is absent rather than null when the error
does not carry it.

Every other JSON-envelope handler in the package calls the same builder —
including `TomUserPreferencesErrorHandler`, whose translated `404`/`400` carry
the same fields, the same header and the same media type. A handler that
translates a status chooses the *status*, not the shape. A body a client is
expected to decode by `errorKey` has to declare that it is JSON: shelf supplies
no default here, and an undeclared body leaves a client with only `x-tom-error`
to guess from and an intermediary free to sniff it as anything it likes.

## Extending the Pipeline

- **Authentication** — set `authenticationMiddleware` on the configuration to
  replace `tomDefaultAuthenticationMiddleware`. A substitute is responsible for
  everything the default established: the zone values — at minimum
  `TomPrincipal` and `TomRequestId` (the one `tomRequestContextMiddleware`
  already put in the zone, read with `getFromCurrentZone<TomRequestId>()`) — and the
  `TomTransactionManager.runInTransactionScope` around them, and, with a
  tenancy installed, the request's tenant; and, for an API-key limit to count
  anything, the `TomApiKeyIdentity` of a request a key authenticated. Everything below
  the middleware reads those from the ambient zone rather than being passed
  them, so omitting one is not a compile error. Drop the transaction scope and
  repository code silently falls back to the per-isolate current transaction
  described above; drop `TomRequestId` and `TomServerException` loses its
  correlation.
- **Logging** — set `loggingMiddleware` (defaults to `tomLoggingMiddleware`).
  Shelf's own `logRequests()` drops in unchanged and adds request timing, which
  the default does not report. It reads nothing from the request context,
  though, so it honours neither guard: every endpoint that opted out with
  `logRequests: false` — `/health` above all — starts logging again, and a
  retried request logs once per pass. Take it when timing matters more than the
  opt-out.
- **Pre/post handlers** — set `preExecutionHandler` / `postExecutionHandler` to
  cascade handlers around the router (e.g. static assets, fallbacks).
- **Errors** — set `errorHandler` / `authenticationErrorHandler`.

## Metrics

**The server records metrics, and exposes them for Prometheus and over OTLP.**
This is a facility of the framework rather than an endpoint an application
declares: an enterprise operator expects request rates, latencies and pool
usage out of the box, and a series a module records about itself — a
statement's duration, a pool's waiters, a job's lag — cannot be recorded from
an endpoint.

The instruments live in `tom_core_kernel`'s `metrics` module, where the
scheduler records its job series; the server records its requests, statements,
pool usage, cache lookups and rate-limit refusals into the same process
registry, `TomMetrics.registry`. What reads them is configuration:

| Key | Default | Effect |
| --- | ------- | ------ |
| `metricsEndpoint` | `false` | Answer Prometheus scrapes, ahead of authentication |
| `metricsPath` | `/metrics` | The path scrapes are answered at |
| `metricsToken` | empty | The bearer token a scrape must present; empty leaves the endpoint open |
| `otlpEndpoint` | empty | The OTLP/HTTP receiver `start()` pushes metrics to; empty pushes none |
| `otlpHeaders` | empty | Headers of every export, as `key=value,key=value` |
| `otlpMetricsIntervalSeconds` | `60` | How often metrics are pushed |

The series are recorded whether or not anything reads them; both exports read
the same instruments, so a series exists once however it leaves the process.
`start()` creates the OTLP exporter as `TomServer.metricsExporter` and registers
it with the shutdown cleanup, which pushes once more before the process ends.
The series, their labels and the exporter are described in
[metrics.md](metrics.md).
<!-- pinned: test/metrics_test.dart › exposes the request, cache, rate-limit and job series -->

## Graceful Shutdown

An orchestrator stopping a server sends SIGTERM, waits its grace period, then
kills the process. What the server does in between decides three things: whether
the requests in flight are answered, whether the scheduled work it holds is
taken over by another node at once or only after its lease expires, and whether
its database connections are closed or simply dropped.

`start()` hands the bound socket to `TomServer.gracefulShutdown`, a
`TomGracefulShutdown` built from the configuration, and registers it with the
kernel's `tomShutdownCleanup` as a signal handler for **SIGTERM and SIGINT**
(SIGTERM where the platform can watch it — not on Windows). Either signal runs
the shutdown, in this order:

1. **Not ready.** `GET /ready` answers `503 shutting down`
   (`TomHealthServer.markShuttingDown`), so a load balancer stops sending new
   traffic. `GET /health` still asks its liveness analyzer: a draining process is
   alive, and restarting it would cut off the requests it is finishing. See
   [healthcheck.md](healthcheck.md#while-the-server-shuts-down).
2. **Readiness delay.** Requests are still accepted for
   `shutdownReadinessDelaySeconds` — zero by default — the time a load balancer
   needs to notice the `503`.
3. **Stop accepting.** The listener closes, so no new connection is accepted.
   A request arriving on a connection kept alive from before is answered `503`
   with `Connection: close` and `Retry-After: 1` by the shutdown gate, the
   outermost layer of [the pipeline](#the-pipeline); a client or proxy retries
   it elsewhere. The probe paths (`tomProbePaths`: `health`, `ready`) still
   pass, so on such a connection the orchestrator sees a live, unready process.
4. **Drain.** Every started scheduler (`TomScheduler.started`) — the message
   outbox's own scheduler included — is stopped, so no new run begins. The
   requests in flight and the runs already started get until the deadline,
   `shutdownGracePeriodSeconds` after this step began, to finish.
5. **Hand back.** Once the responses of the answered requests are written, every
   started outbox (`TomMessageOutbox.started`) and scheduler is closed, which
   releases their leases, so another node takes the work at once rather than
   after the lease's time-to-live. A run still going at the deadline is not
   waited for any further, and its lease is released with the others — so a
   peer may take that work on while this process is still ending. Connections
   still open at the deadline are closed.
6. **Close the pools** of every registered data source
   (`TomDataSourceInfo.closeAll`).

A closing step that fails — an outbox, a scheduler, the listener, the pools —
is logged as a warning and the next one runs, so one broken outbox does not
keep the pools open. The shutdown logs one line when it starts, with the number
of requests in flight, and one when it finishes, with how long it took; running
out of the grace period is a warning.

After the signal-handler phase, `tomShutdownCleanup` runs the closables and
disposables registered with it — the OTLP exporter's final push among them —
and then, with `exitOnShutdownSignal` on (the default), ends the process with
exit code `0`. An orchestrator waits for the process to exit; one that lingered
after its shutdown would be killed at the end of the grace period instead. With
the setting off the process is left to end once nothing keeps it alive.
`start()` raises the cleanup's phase timeout to the readiness delay plus the
grace period plus five seconds, because the whole shutdown runs inside the
signal-handler phase, which would otherwise be abandoned after its default ten
seconds.

`TomServer.shutdown()` runs the same steps without a signal — for a supervisor
or a test that embeds a server. It never ends the process, and it is
idempotent: a second call, or a signal after the call, is handed the shutdown
already under way.

```dart
final server = TomServer(configuration);
await server.start();
// … later, from a supervisor rather than a signal:
await server.shutdown();   // readiness off, drained, leases released, pools closed
```

### What it waits for

**Requests, by count.** The shutdown gate counts every request that passes it
and the drain waits for that count to reach zero. A handler returning is not its
response written, though — shelf writes the response afterwards — so the
shutdown then waits for the socket's open connections to reach zero: once the
listener is closed an idle connection is closed at once and an answered one
after its response, so the last connection closing is the last response
written. A metrics scrape is a request like any other here: counted while it
runs and refused once the server is draining.

**Scheduled runs, by scheduler.** A scheduler's runs are drained through
`TomScheduler.drain` after `stop`, and closing it afterwards is what releases
the leases it holds — `close` before the run had finished would hand the work
to another node while this one is still doing it.

**The grace period is one deadline, not one per step.** Requests, runs and
connections share it. What is unfinished at the deadline is not waited for any
further: the outboxes and schedulers are closed regardless, releasing every
lease they hold, the listener is force-closed, and the pools are closed.

### Configuration

| Key | Default | Effect |
| --- | ------- | ------ |
| `shutdownGracePeriodSeconds` | `20` | How long the requests in flight and the running scheduled work get to finish once the listener is closed. Environment name `SHUTDOWN_GRACE_PERIOD_SECONDS` |
| `shutdownReadinessDelaySeconds` | `0` | How long requests are still accepted after `/ready` turned to `503`. Environment name `SHUTDOWN_READINESS_DELAY_SECONDS` |
| `exitOnShutdownSignal` | `true` | Whether a SIGTERM or SIGINT ends the process once the shutdown and every cleanup phase after it have run. Environment name `EXIT_ON_SHUTDOWN_SIGNAL` |

See [configuration.md](configuration.md#graceful-shutdown).

### Kubernetes

Deleting a pod starts two things at once: the kubelet sends SIGTERM (after a
`preStop` hook, when one is declared), and the pod is removed from its
Service's endpoints. The second takes a moment to reach every proxy and load
balancer, so for that moment new connections still arrive. Three settings
decide what happens to them and to the work in flight.

**`terminationGracePeriodSeconds`** (30 by default) is the orchestrator's own
deadline, counted from the start of termination; after it the process is
killed whatever it is doing, and no lease is released and no pool closed. The
server's own budget has to fit inside it with room to exit:

```text
preStop sleep + shutdownReadinessDelaySeconds + shutdownGracePeriodSeconds + ~5 s  <  terminationGracePeriodSeconds
```

The defaults — no delay, a twenty-second grace period — fit the default thirty.

**The readiness delay or a `preStop` sleep** covers the moment the endpoint
removal takes to arrive; use one, not both. A `preStop` hook that sleeps holds
SIGTERM back, so the server serves normally until the traffic has moved, but it
needs a `sleep` in the image or the `sleep` action of newer Kubernetes
versions. `shutdownReadinessDelaySeconds` does the same inside the server
after SIGTERM, with `/ready` already answering `503` — which also takes the pod
out of any load balancer that routes by probing `/ready` itself — and needs
nothing in the image. Behind a Service set it to the readiness probe's
`periodSeconds` plus its `timeoutSeconds`. A server that is reached directly
rather than through a load balancer needs neither, which is why the delay
defaults to zero.

**The probes.** Readiness turns to `503` at the first step, and liveness keeps
answering `200`, so the drain is never mistaken for a hung process. Once the
listener has closed, though, a probe arriving on a *new* connection is refused
— the kubelet opens one per probe — so a liveness probe would start failing
then. Keep its `failureThreshold` × `periodSeconds` above the grace period: the
probe configuration in [healthcheck.md](healthcheck.md#kubernetes) allows thirty
seconds against the default twenty.

```yaml
spec:
  terminationGracePeriodSeconds: 45     # 15 + 20 + margin to exit
  containers:
    - name: server
      env:
        - name: SHUTDOWN_READINESS_DELAY_SECONDS
          value: "15"                   # readiness periodSeconds 5 + timeoutSeconds 10
        - name: SHUTDOWN_GRACE_PERIOD_SECONDS
          value: "20"
      readinessProbe:
        httpGet: { path: /ready, port: 8080 }
        periodSeconds: 5
        timeoutSeconds: 10
        failureThreshold: 2
      livenessProbe:
        httpGet: { path: /health, port: 8080 }
        periodSeconds: 10
        timeoutSeconds: 10
        failureThreshold: 3             # 30 s, above the 20 s grace period
```

Run the server as the container's main process (`exec` in an entrypoint
script, not a shell that forwards nothing), so SIGTERM reaches the Dart
process at all.

## Verification

Three suites cover this module, a fourth covers its endpoint-owned
credentials, a fifth its tenant resolution, a sixth the API keys and rate
limits it reads, a seventh the metrics middlewares it installs, an eighth
its correlation ids and log format, a ninth its graceful shutdown, and a tenth
the resilience of its outgoing HTTP calls.

`test/server_test.dart` covers the pipeline as composed functions:
`TomRequestLogInfo`, `extractAuthentication` reading a credential off a request
— naming each `TomCredentialOutcome`, and holding the battery that requires no
refused token to appear in any line the module writes —
`verifyBearerToken` refusing a token this deployment did not sign,
`contextSetupMiddleware`, `tomRequestLogInfoMiddleware` (a new record per
request) and `tomLoggingMiddleware`,
`tomDefaultAuthenticationMiddleware` — including the case where the cached
principal has expired and the credentials survive it — and `TomServer`'s
constructor wiring and error handler. None of that needs a bound port, because
a middleware is a function of a request.

It also drives `start()` against real sockets on the loopback interface. Two
properties are worth naming. **The deployment is logged in before the socket
accepts**: a stub auth server in the suite holds the login open, and while it is
held a connection to the port `start()` is about to bind is refused — a server
that bound first would answer it, and would be serving requests with user grants
uncapped. **A configured deployment that cannot log in binds nothing**: the port
is still free afterwards, which says more than "the future rejected" — it says
`serve` was never reached. The same ordering is read from the *source* by
`test/api_reference_coverage_test.dart`, because a rewrite that keeps both calls
and swaps them compiles and passes everything a running server can be asked.

`test/server_self_login_test.dart` covers the deployment logging in as itself:
reading `TomServiceCredential` out of the configuration, `logIn`,
`loginAndInstall`, and the end-to-end consequence that gives the feature its
point — the installed principal capping what a user's grants can reach.

`test/server_exception_family_test.dart` is a reading of the source tree rather
than of behaviour: every exception class in the package is a
`TomServerException`, so one `on TomServerException` in the pipeline reaches all
of them.

The two metrics middlewares at the outer edge are covered by
`test/metrics_test.dart`, which composes them in the order `start()` does: a
request counted under its route pattern, an unmatched path, an escaping error
counted as a `500`, and a scrape that is answered before — and so not counted
by — the request series. See [metrics.md](metrics.md#verification).

`test/structured_logs_readiness_test.dart` covers the correlation ids and the
log format. In the group `request context` it runs requests through
`tomRequestContextMiddleware` and `tomDefaultAuthenticationMiddleware` stacked
as `start()` stacks them: a caller's `traceparent` continued with a span of the
server's own, a missing or invalid one starting a trace, the request id kept by
authentication and named on the response, and a line logged while serving
carrying `trace_id`, `span_id`, `request_id` and `tenant` and no other field
beyond the fixed ones. The group `logFormat` pins `applyLogFormat`: `json`
replacing the default console output, an application's own output kept, `text`
changing nothing and an unknown value refused. The group `a started server`
binds a socket and reads the `X-Request-Id` and `traceparent` response headers
off a real response.

`TomEndpointCredentials` is exercised where it is used: `test/scim_test.dart`'s
test `the framework leaves the claimed header to the endpoint` reads a SCIM
request as `endpointCredential` and the same header on an unclaimed path as
`unreadableToken`, and the rest of that suite reaches the SCIM endpoints
through the pipeline with the identity provider's secret.

`test/tenancy_test.dart`, in the group `the request pipeline`, runs requests
through `tomDefaultAuthenticationMiddleware` with a tenancy installed: a request
runs inside the tenant it names, a token used for another tenant is refused with
`403`, and a deployment without tenancy runs every request in none.

`test/ratelimit_test.dart`, in the group `the middleware`, runs requests
through `tomDefaultAuthenticationMiddleware` and `tomRateLimitMiddleware`
stacked as `start()` stacks them: an API key authenticating its request and
counted per key, a refused key proceeding anonymous and counted by its address,
and no limits installed leaving every response unannotated.

`test/graceful_shutdown_test.dart` covers the graceful shutdown. Its group
`SIGTERM to a server process` starts `test/fixtures/graceful_shutdown_server.dart`
— a `TomServer` with a slow path and a scheduler whose job holds a file lease —
and sends it a real SIGTERM during a slow request: the request completes with
`200`, a new request is refused or finds the port closed, the process exits
with `0`, and the lease is released rather than left to its ten-minute
time-to-live. That group is skipped on Windows, where SIGTERM cannot be sent.
The group `TomGracefulShutdown in process` drives the same shutdown in-process,
one step at a time: a request in flight drained while a new one is refused with
`503` and `Connection: close` and the probe paths pass, readiness answering
`503` while liveness answers `200`; a scheduler stopped, its run waited for and
its lease released only afterwards; a run past the grace period abandoned and
its lease released; and a second call handed the first shutdown.

`test/http_client_resilience_test.dart` covers the `httpClient` key and the
framework's own call paths. The group `configuration` applies a map through
`TomServer.configureHttpClients` — the defaults and a destination's policy set
from it, the defaults standing without it, and a value that is not a map
refused with `http.client.config.invalid`. The group `framework call paths`
runs against a local server that fails on purpose: a `TomServerChannel` call
retried through a `503`, and the OAuth transport retrying its user-info `GET`
and sending its token `POST` once. The policies themselves are the kernel's and
are tested there.

```bash
dart run example/server/server_example.dart
dart run example/server/graceful_shutdown_example.dart
```

`example/server/server_example.dart` exercises the socket-free surface the
server is composed from — the per-request log state, the credential reader
(including the three outcomes that answer `(null, null)` alike and are still
told apart), and two middlewares. It binds no socket: an example is read as much
as run, and a listening port in one is a process a reader has to know to stop.
The bind is covered by the suite instead.
`example/server/graceful_shutdown_example.dart` runs a graceful shutdown step by
step around a handler and a scheduler of its own — a request in flight,
readiness turning to `503`, a new request refused, a probe passed, the scheduler
stopped and its run drained, the lease released — without a socket or a
signal, which the suite covers. Every step of both checks its own result, and
`test/examples_test.dart` runs them.

## Not Yet Implemented

Every limitation below has a consequence a caller can observe — a status that
does not distinguish, a request that leaves no trace, a failure that arrives
somewhere other than the call site.

- **The default `errorHandler` answers `500` for everything.** It renders the
  error envelope faithfully, but the status is fixed, so a not-found, a
  forbidden and a validation failure are indistinguishable to a client that
  reads the status line rather than decoding the body. Nothing in the package
  maps an exception kind to a status on its own: `TomDefaultErrorHandler`, the
  endpoint pipeline's fallback, answers `500` too. Choosing the status is a
  handler's job, and `TomUserPreferencesErrorHandler` is the worked example — an
  `errorKey`-to-status map, the same `tomErrorEnvelope` body, and only the
  *status* contributed. See [Error Mapping](#error-mapping).
  <!-- pinned: test/api_reference_coverage_test.dart › the server guide's Not Yet Implemented section matches the module -->

`extractAuthentication` reports every way a credential can fail — by a named
`TomCredentialOutcome` and, for each refusal, by a warning naming the reason
without the credential in it; see [The Pipeline](#the-pipeline). What it does
not do is distinguish them to the *HTTP client*, and that is
deliberate rather than outstanding: a client who could tell "your signature was
wrong" from "you sent nothing" is an attacker who can tell whether they guessed.
The operator gets the detail; the client gets one answer.

### What this module does not do at all

Two capabilities a reader may come here looking for are not gaps waiting to be
filled. They are not this module's surface, nothing here is planned for them,
and an application that needs one builds it today rather than waiting:

- **Server-rendered forms.** *Receiving* a form is shipped, and belongs to the
  endpoints module — see [Multipart Forms](endpoints.md#multipart-forms).
  Rendering one is a templating concern rather than a transport one, so it sits
  outside this package rather than pending inside it.
  <!-- unpinned: pointer — receiving forms is the endpoints module's -->
- **WebSocket.** Also the endpoint pipeline's: a socket is served as a kind of
  endpoint, declared like any other — see
  [WebSocket Endpoints](endpoints.md#websocket-endpoints).
  <!-- unpinned: pointer — sockets are the endpoint pipeline's -->

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | every file | `Future`, `FutureOr`, `unawaited`, and the `Completer` and `TimeoutException` the shutdown waits with |
| `dart:convert` | dart | `server.dart` | `json`, `jsonEncode`, `utf8` |
| `dart:io` | dart | every file | `HttpServer`, `InternetAddress`, `SecurityContext`, `ProcessSignal` (SIGTERM, SIGINT), `HttpHeaders` |
| `shelf` | package | every file | the HTTP pipeline, `Request`/`Response`/`Handler`/ `Middleware`/`Router`/`Cascade`, and `serve` |
| `shelf_router` | package | `server.dart` | the HTTP pipeline, `Request`/`Response`/`Handler`/ `Middleware`/`Router`/`Cascade`, and `serve` |
| `tom_core_kernel` | package | every file | `TomPrincipal`, `TomClientJwtToken`, `TomBearerAuthentication`, `TomExecutionContext`/`tomExecutionContext`, `TomZoneValues`, `tomLog`, `tomPrintStackTrace`, `TomException`, `TomTraceContext` and `TomLogContext` (the request's trace and the `request_id` log field), `TomJsonLogOutput` / `TomConsoleLogOutput` (`logFormat`), `tomShutdownCleanup` (the signals the graceful shutdown runs on), `TomScheduler.started` (the schedulers it drains) and `TomHttpResilience` / `TomHttpResilienceException` (`configureHttpClients`) |
| [authentication](authentication.md) | module | `server.dart` | `TomServerSelfLogin`, `TomServerSelfLoginException`, `TomApiKeys` and `TomApiKeyIdentity` (a service account's API key) |
| [authorization](authorization.md) | module | `server.dart` | `TomAuthorizationCache` (principal resolution) |
| [configuration](configuration.md) | module | `server.dart` | `TomBaseServerConfiguration` |
| [datasources](datasources.md) | module | `graceful_shutdown.dart` | `TomDataSourceInfo.closeAll`, the graceful shutdown's last step |
| [endpoints](endpoints.md) | module | `server.dart` | `TomEndpointRouting` (router initialisation), `TomOpenApiServer` (the OpenAPI document path, set from `openApiDocument`), `TomIdempotency` (`configureIdempotency` applies the `idempotency` key) |
| [healthcheck](healthcheck.md) | module | every file | `TomFrameworkReadinessAnalyzer`, installed on `GET /ready` by `start()` when `frameworkReadiness` is on, `TomHealthServer` / `TomDefaultHealthAnalyzer` to see whether the application installed its own, and `TomHealthServer.markShuttingDown`, the graceful shutdown's first step |
| [little_things](little_things.md) | module | `server.dart` | `TomServerException` (its `clientThrow` flag feeds the error response) and `TomRequestId` (minted by `tomRequestContextMiddleware`, carried into every request zone) |
| [messaging](messaging.md) | module | `graceful_shutdown.dart` | `TomMessageOutbox.started`, the outboxes the graceful shutdown closes |
| [metrics](metrics.md) | module | `server.dart` | `tomMetricsEndpointMiddleware` and `tomRequestMetricsMiddleware` (the outer edge of the pipeline), `TomOtlpHttpTransport` and `TomOtlpMetricsExporter` (`metricsExporter`) |
| [object_persistence](object_persistence.md) | module | `server.dart` | `TomFieldEncryption` (`configureFieldEncryption` applies the `fieldEncryption` key) |
| [privacy](privacy.md) | module | `server.dart` | `TomPrivacy` (`configurePrivacy` applies the `privacy` key) |
| [ratelimit](ratelimit.md) | module | `server.dart` | `TomRateLimits` (installed from configuration at start) and `tomRateLimitMiddleware` |
| [tenancy](tenancy.md) | module | `server.dart` | `TomTenancy` and `TomTenantResolution` — the request's tenant, or the refusal to answer it with |
| [transactions](transactions.md) | module | `server.dart` | `TomTransactionManager`, and `TomTransactionRecovery` / `TomRecoveryReport` (`recoverTransactions` applies the `transactions` key and recovers at start) |
