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

`TomServer` reads everything it needs from the configuration: TLS material
(`certificateChain` / `privateKey`, unless `noSsl`), the listen address (`host`,
or any-IPv4 when empty or `listenToAnyIP`), the `port`, `isolateCount` (sockets
are `shared` when more than one), `autoCompress`, and the `serverHeader` /
`poweredByHeader`. `start()` is fire-and-forget — it begins listening and logs
the bound address; it does not return the `HttpServer`.

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

Two channels carry per-request state:

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

`extractAuthentication` is the credential reader: it parses a `Bearer <jwt>`
`Authorization` header into a `(TomPrincipal?, TomClientJwtToken?)` record,
returning nulls when the header is absent, not a bearer token, or fails to parse
(an invalid token is treated as "no credentials", not an error).

## Error Mapping

`TomServer.errorHandler` turns a thrown error into an HTTP 500 JSON response
carrying the `x-tom-error: true` header. The body always includes
`errorType`; a `TomException` additionally contributes `errorKey`, `uuid`,
`autoLog`, and `requestUuid`; and a `TomServerException` adds `clientThrow`.
Provide `TomBaseServerConfiguration.errorHandler` /
`authenticationErrorHandler` to override the mapping.

## Extending the Pipeline

- **Authentication** — set `authenticationMiddleware` on the configuration to
  replace `tomDefaultAuthenticationMiddleware`.
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

## Not Yet Implemented

The module ships nothing for the capabilities below — no type, no export, no
placeholder file. Each is named here so that a reader who goes looking finds out
it is absent, rather than concluding they have missed where it lives:

- **Diagnostics** — server diagnostics/introspection endpoints.
- **Monitoring** — runtime metrics / monitoring hooks.
- **Server-side forms** — server-rendered form support. *Receiving* a form is
  shipped — see
  [Multipart Forms](endpoints.md#multipart-forms) — what is missing is rendering
  one server-side, which is a templating concern rather than a transport one.

WebSocket support is not among them: it is served by the endpoint
pipeline as a kind of endpoint — see
[WebSocket Endpoints](endpoints.md#websocket-endpoints).

## Dependencies

- `shelf` / `shelf_router` — the HTTP pipeline, `Request`/`Response`/`Handler`/
  `Middleware`/`Router`/`Cascade`, and `serve`.
- `tom_core_kernel` — `TomPrincipal`, `TomClientJwtToken`,
  `TomBearerAuthentication`, `TomExecutionContext`/`tomExecutionContext`,
  `TomZoneValues`, `tomLog`, `tomPrintStackTrace`, `TomException`.
- The little-things module — `TomServerException` (its `clientThrow` flag feeds
  the error response) and `TomRequestId` (seeded into every request zone).
- The configuration module — `TomBaseServerConfiguration`.
- The endpoints module — `TomEndpointRouting` (router initialisation).
- The authorization module — `TomAuthorizationCache` (principal resolution).
