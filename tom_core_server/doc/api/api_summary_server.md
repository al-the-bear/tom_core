# Tom Core Server API Reference: Server Module

The HTTP entry point of a Tom server application: the `TomServer` that assembles
a shelf pipeline (context setup, error handling, authentication, logging) in
front of the endpoint router and binds it to a socket, plus the middleware,
helpers, and per-request state that make up that pipeline.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomRequestLogInfo](#tomrequestloginfo)
  - [TomServer](#tomserver)
  - [TomEndpointCredentials](#tomendpointcredentials)
- [Enums](#enums)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tomserver/server/server.dart`.

`TomServer` is built from a `TomBaseServerConfiguration`. Its `start` method
first logs the deployment in as itself — `TomServerSelfLogin.loginAndInstall`,
which installs the `TomServerPrincipal` that caps every user's grants, and which
aborts the start with no socket bound when a configured credential is refused —
then initialises the endpoint `Router` (via `TomEndpointRouting`), composes a
shelf `Pipeline` — `tomRequestLogInfoMiddleware` (seeds a new
`TomRequestLogInfo` per request), `tomLoggingMiddleware`, an outer error layer,
`tomDefaultAuthenticationMiddleware`, `tomRateLimitMiddleware` (the ratelimit module's) and an inner error layer — optionally wraps the router in a `Cascade` with
pre/post handlers, and binds the socket (with TLS unless `noSsl`).

The module exposes the composable middleware as top-level functions
(`contextSetupMiddleware`, `tomRequestLogInfoMiddleware`,
`tomDefaultAuthenticationMiddleware`, `tomLoggingMiddleware`), a credential helper (`extractAuthentication`) with the
`TomCredentialOutcome` it reports, `TomEndpointCredentials` — the paths whose
`Authorization` header the credential helper leaves to the endpoint — and a
`noopHandler`. Per-request state travels in the request context
(`TomRequestLogInfo`), the request zone, and — because the authentication
middleware also opens a `TomTransactionManager.runInTransactionScope` — the
current transaction. The zone-carried correlation id
`TomRequestId` is *produced* here — `tomDefaultAuthenticationMiddleware` puts a
fresh one into `zoneValues` for every request — but declared in `little_things`,
beside the exception base that consumes it, so that the most depended-upon
module of the package does not have to import the largest one. It is documented
in
[api_summary_little_things.md](api_summary_little_things.md#tomrequestid).

## Class Hierarchy

```text
TomRequestLogInfo        (standalone)
TomServer                (standalone)
TomEndpointCredentials   (abstract final, statics only)
```

All three classes are standalone (no Tom base class).

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

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* Compact `should=`/`has=` description. |

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
| `errorHandler` | `Response? Function(Request, Object, StackTrace)` | Maps a thrown error to a JSON error response (HTTP 500), declared `Content-Type: application/json` and marked `x-tom-error: true`; overridable via the configuration. The body is [`tomErrorEnvelope`](api_summary_little_things.md#tomerrorenvelope) — the package's single definition of the wire error shape, which this handler renders and does not define. |
| `authenticationErrorHandler` | `Response? Function(Request, Object, StackTrace)?` | Error handler applied by the outer pipeline layer; defaults to the configuration's handler, falling back to `errorHandler`. |
| `loggingMiddleware` | `Middleware` | The middleware that emits the per-request access log (`late`; from the configuration). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `warnOnDevelopmentTlsMaterial` | `void warnOnDevelopmentTlsMaterial()` | Warns when this server is about to serve TLS with the checked-in development pair, naming which half is still at its default. Called by `start` before it builds the `SecurityContext`. Silent when `noSsl` is set, since nothing is served over TLS. Nothing refuses to start: an opt-in flag would cost every local TLS run an extra setting. Public and separate from `start` because `start` binds a socket and returns nothing, so a property of the boot is otherwise unobservable. |
| `warnOnUnenforcedResourceKeys` | `void warnOnUnenforcedResourceKeys()` | Warns when this server is about to serve with resource-key grants unenforced (`tom.protection.resourceKeys` off, the default) outside a development or test environment, naming the setting that changes it. Called by `start` before the socket is bound. Silent when enforcement is on or the environment is development or test. Nothing refuses to start: the default stays off because enforcing refuses every undeclared endpoint of an application with no grants configured. |
| `start` | `Future<HttpServer> start()` | Logs the deployment in as itself (`TomServerSelfLogin.loginAndInstall`) before anything else, then warns if the TLS material is still the development pair, installs the rate limits the `rateLimits` configuration key describes when none were installed (`TomRateLimits.fromConfiguration`), initialises the router, composes the pipeline, builds TLS, resolves the listen address, and binds the socket. The future completes **when the socket is listening**, with the bound `HttpServer` — so a bind failure rejects it rather than surfacing as an unhandled asynchronous error, and the socket can be closed by its opener. A deployment that configured a service credential and cannot log in has the error rethrown and **no socket is bound**; one that configured none is unaffected. Awaiting is optional: the bound socket keeps the isolate alive on its own. |

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
| `tomRequestLogInfoMiddleware` | `Middleware tomRequestLogInfoMiddleware()` | Seeds a new `TomRequestLogInfo` under `TomRequestLogInfo.contextName` into every request's context — one instance per request, because `tomLoggingMiddleware` marks it logged and the endpoint pipeline sets whether it should be. `TomServer.start` installs it outermost. |
| `extractAuthentication` | `(TomPrincipal?, TomClientJwtToken?, TomCredentialOutcome) extractAuthentication(Request req)` | Extracts bearer credentials from the `Authorization` header, returning `(principal, token, outcome)`. A header on a path claimed in `TomEndpointCredentials` is not read: the answer is `(null, null, endpointCredential)`. The first two elements are `null` whenever the request is not authenticated; [`TomCredentialOutcome`](#tomcredentialoutcome) says which of the five ways that happened, because `(null, null)` is the answer to all five and an operator cannot act on it. Never raises and never refuses — a public endpoint is served through this same pipeline — but every refusal is recorded at warning level, and never with the credential in it. The scheme is matched case-insensitively, as RFC 7235 requires. |
| `tomDefaultAuthenticationMiddleware` | `Middleware tomDefaultAuthenticationMiddleware(String id, [Map<String, Object>? context])` | The default authentication middleware: resolves the effective `TomPrincipal` — from the bearer token, or, when the request carries no `Authorization` header, from an `X-API-Key` the installed `TomApiKeys` accepts (ignored with a warning when none is installed) — and runs the inner handler in a zone exposing the request, execution context, principal, token, the `TomApiKeyIdentity` of an accepted key, and a fresh `TomRequestId` — and inside a `TomTransactionManager.runInTransactionScope`, so the current transaction is per-request rather than per-isolate. A replacement must establish both. |
| `tomLoggingMiddleware` | `Middleware tomLoggingMiddleware()` | The default request-logging middleware: emits one access-log line per request, guarded by the request's `TomRequestLogInfo`. Both guards are the reason shelf's `logRequests()` is not the default — it reads no request context, so it can honour neither. |
| `noopHandler` | `Handler noopHandler(String id, int statusCode)` | A `Handler` that ignores the request and always replies with `statusCode` (`id` labels it for tracing). |
