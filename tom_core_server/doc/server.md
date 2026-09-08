# Server Module

The HTTP entry point of a Tom server application. `TomServer` takes a
`TomBaseServerConfiguration`, assembles a [shelf](https://pub.dev/packages/shelf)
middleware pipeline in front of the endpoint router, and binds it to a socket.
The module also provides the middleware that the pipeline is built from —
context setup, authentication, error mapping, and request logging — plus
`TomRequestLogInfo`, the per-request logging state that travels in the request
context. The other per-request value object, the correlation id `TomRequestId`,
is *produced* here — the authentication middleware seeds a fresh one into every
request zone — but declared in the little-things module, beside the exception
base that reads it; see [little_things.md](little_things.md#tomrequestid).

## Table of Contents

- [Overview](#overview)
- [Starting a Server](#starting-a-server)
- [The Pipeline](#the-pipeline)
- [Request Context and Zone Values](#request-context-and-zone-values)
- [Error Mapping](#error-mapping)
- [Extending the Pipeline](#extending-the-pipeline)
- [Verification](#verification)
- [Not Yet Implemented](#not-yet-implemented)
- [Dependencies](#dependencies)

---

## Overview

| Symbol | Kind | Purpose |
| ------ | ---- | ------- |
| `TomServer` | class | Composes the pipeline and binds the socket |
| `TomRequestLogInfo` | class | Per-request logging state in the request context |
| `contextSetupMiddleware` | function | Seeds entries into the request context |
| `tomDefaultAuthenticationMiddleware` | function | Extracts credentials and publishes request zone values |
| `tomLoggingMiddleware` | function | Emits the one-shot access-log line, prefixed with the application id |
| `extractAuthentication` | function | Reads bearer credentials from a request |
| `noopHandler` | function | A handler that always returns a fixed status code |

## Starting a Server

```dart
final server = TomServer(configuration); // a TomBaseServerConfiguration
server.start(); // fire-and-forget: binds the socket and starts listening
```

`TomServer` reads everything it needs from the configuration: the service
credential (below), TLS material (`certificateChain` / `privateKey`, unless
`noSsl`), the listen address (`host`, or any-IPv4 when empty or
`listenToAnyIP`), the `port`, `isolateCount` (sockets are `shared` when more
than one), `autoCompress`, and the `serverHeader` / `poweredByHeader`.
`start()` is fire-and-forget — it begins listening and logs the bound address;
it does not return the `HttpServer`.

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
  the socket is never bound**. Because `start()` is fire-and-forget this arrives
  as an unhandled asynchronous error at boot with the log line
  `Server self-login failed — refusing to bind the socket`. Starting anyway
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

1. **`contextSetupMiddleware`** — seeds a fresh `TomRequestLogInfo` into the
   request context under `TomRequestLogInfo.contextName`.
2. **Outer error handler** — catches errors from the authentication phase using
   the `authenticationErrorHandler`.
3. **Authentication middleware** — the configuration's `authenticationMiddleware`
   or `tomDefaultAuthenticationMiddleware`.
4. **Inner error handler** — catches errors from handling using `errorHandler`.
5. **Logging middleware** — `loggingMiddleware` (defaults to
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
6. **Router** — optionally wrapped in a `Cascade` with the configuration's
   `preExecutionHandler` / `postExecutionHandler`.

## Request Context and Zone Values

Three channels carry per-request state:

- **The shelf request context** holds `TomRequestLogInfo` (keyed by
  `TomRequestLogInfo.contextName`). Set its `shouldBeLogged` to `false` to
  suppress the access-log line for a request (e.g. health checks); the logging
  middleware also flips `hasBeenLogged` so the line is emitted at most once.
- **The request `Zone`** (established by `tomDefaultAuthenticationMiddleware`)
  exposes a `TomZoneValues` bundle: the shelf `Request`, the ambient
  `TomExecutionContext`, the resolved `TomPrincipal`, the `TomClientJwtToken`,
  and a fresh `TomRequestId` (declared in the little-things module). Downstream
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
`Authorization` header into a `(TomPrincipal?, TomClientJwtToken?)` record,
returning nulls when the header is absent, not a bearer token, or fails to parse
(an invalid token is treated as "no credentials", not an error).

The principal the zone finally carries is resolved from those two: a principal
`TomAuthorizationCache` holds for the token wins, a cache miss falls back to the
one `extractAuthentication` decoded, and an entry the cache reports as **expired**
resolves to no principal at all — the same answer an uncredentialed request
gets. The middleware itself never refuses; a protected endpoint refuses the
request downstream, and a refresh or re-login endpoint stays reachable with the
token still in the zone. See
[authorization.md](authorization.md#an-expired-entry-resolves-to-no-principal)
for why the token-derived principal is not used as the fallback there.

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
  `TomPrincipal` and `TomRequestId` — and the
  `TomTransactionManager.runInTransactionScope` around them. Everything below
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

## Verification

Three suites cover this module, split by what each can be asked without a
socket.

`test/server_test.dart` covers the pipeline as composed functions:
`TomRequestLogInfo`, `extractAuthentication` reading a credential off a request,
`verifyBearerToken` refusing a token this deployment did not sign,
`contextSetupMiddleware` and `tomLoggingMiddleware`,
`tomDefaultAuthenticationMiddleware` — including the case where the cached
principal has expired and the credentials survive it — and `TomServer`'s
constructor wiring and error handler. None of that needs a bound port, because
a middleware is a function of a request.

`test/server_self_login_test.dart` covers the deployment logging in as itself:
reading `TomServiceCredential` out of the configuration, `logIn`,
`loginAndInstall`, and the end-to-end consequence that gives the feature its
point — the installed principal capping what a user's grants can reach.

`test/server_exception_family_test.dart` is a reading of the source tree rather
than of behaviour: every exception class in the package is a
`TomServerException`, so one `on TomServerException` in the pipeline reaches all
of them.

```bash
dart run example/server/server_example.dart
```

`example/server/server_example.dart` exercises the socket-free surface the
server is composed from — the per-request log state, the credential reader, and
two middlewares. `TomServer.start()` binds a real socket and needs a reflected
configuration plus TLS material, so the assembled server is described here
rather than run there. Every step checks its own result, and
`test/examples_test.dart` runs it.

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
- **A request answered above the logging middleware leaves no access-log line.**
  `loggingMiddleware` sits below the authentication layer (see
  [The Pipeline](#the-pipeline)), so whatever is decided above it — the outer
  error handler, or a substitute `authenticationMiddleware` that rejects —
  returns without ever reaching it. `tomDefaultAuthenticationMiddleware` never
  rejects — an expired cached principal resolves to no principal rather than to
  a refusal, and the request is logged like any other — so under the default
  the way in is narrow: a cache read forwarded to another isolate that fails, or
  a transaction scope that cannot be opened. A deployment that supplies a
  rejecting middleware loses the line for every rejection, which is the class of
  request most worth having one.
- **`start()` cannot be awaited and hands back no handle.** It is
  `void … async`, so a failure after the self-login — a port already in use, an
  unreadable certificate — arrives as an unhandled asynchronous error rather
  than at the call site, and the caller never receives the bound `HttpServer`
  to close. That the socket is bound at all is observable only through the log
  line `start()` emits.

All three are pinned by tests in `test/api_reference_coverage_test.dart`, in the
group "the server guide's Not Yet Implemented section matches the module", so
closing one turns a test red rather than leaving this section quietly wrong.
There were four: `extractAuthentication` could not report a bad token, because
it swallowed both its failures into empty catches. It reports both now — the
signature rejection from `verifyBearerToken` and the derivation failure at the
call site, each at warning level with its reason.

What it still does not do is *distinguish* them to the caller. An absent header,
a non-bearer scheme, an unverifiable token and a verified token that yields no
principal all answer `(null, null)`, and that is deliberate rather than
outstanding: a caller who could tell "your signature was wrong" from "you sent
nothing" is an attacker who can tell whether they guessed. The operator gets the
detail, through the log; the caller gets one answer.

### What this module does not do at all

Three capabilities a reader may come here looking for are not gaps waiting to be
filled. They are not this module's surface, nothing here is planned for them,
and an application that needs one builds it today rather than waiting:

- **Diagnostics and monitoring.** The module has no introspection or metrics
  facility and none is intended. What a deployment can observe is the access-log
  line `tomLoggingMiddleware` emits, the health endpoint from the `healthcheck`
  module, and whatever its own `preExecutionHandler` records. An introspection
  or metrics route is an ordinary endpoint — declare it like any other, see
  [endpoints.md](endpoints.md).
- **Server-rendered forms.** *Receiving* a form is shipped, and belongs to the
  endpoints module — see [Multipart Forms](endpoints.md#multipart-forms).
  Rendering one is a templating concern rather than a transport one, so it sits
  outside this package rather than pending inside it.
- **WebSocket.** Also the endpoint pipeline's: a socket is served as a kind of
  endpoint, declared like any other — see
  [WebSocket Endpoints](endpoints.md#websocket-endpoints).

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | every file | `Future`, `FutureOr` |
| `dart:convert` | dart | every file | `json`, `jsonEncode`, `utf8` |
| `dart:io` | dart | every file | `HttpServer`, `InternetAddress`, `SecurityContext` |
| `shelf` | package | every file | the HTTP pipeline, `Request`/`Response`/`Handler`/ `Middleware`/`Router`/`Cascade`, and `serve` |
| `shelf_router` | package | every file | the HTTP pipeline, `Request`/`Response`/`Handler`/ `Middleware`/`Router`/`Cascade`, and `serve` |
| `tom_core_kernel` | package | every file | `TomPrincipal`, `TomClientJwtToken`, `TomBearerAuthentication`, `TomExecutionContext`/`tomExecutionContext`, `TomZoneValues`, `tomLog`, `tomPrintStackTrace`, `TomException` |
| [authentication](authentication.md) | module | every file | `TomServerSelfLogin`, `TomServerSelfLoginException` |
| [authorization](authorization.md) | module | every file | `TomAuthorizationCache` (principal resolution) |
| [configuration](configuration.md) | module | every file | `TomBaseServerConfiguration` |
| [endpoints](endpoints.md) | module | every file | `TomEndpointRouting` (router initialisation) |
| [little_things](little_things.md) | module | every file | `TomServerException` (its `clientThrow` flag feeds the error response) and `TomRequestId` (seeded into every request zone) |
| [transactions](transactions.md) | module | every file | `TomTransactionManager` |
