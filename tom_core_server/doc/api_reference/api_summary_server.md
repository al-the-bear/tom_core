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
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tomserver/server/server.dart`.

`TomServer` is built from a `TomBaseServerConfiguration`. Its `start` method
initialises the endpoint `Router` (via `TomEndpointRouting`), composes a shelf
`Pipeline` — `contextSetupMiddleware` (seeds a `TomRequestLogInfo`), an outer
error layer, `tomDefaultAuthenticationMiddleware`, an inner error layer, and
`tomLoggingMiddleware` — optionally wraps the router in a `Cascade` with pre/post
handlers, and binds the socket (with TLS unless `noSsl`).

The module exposes the composable middleware as top-level functions
(`contextSetupMiddleware`, `tomDefaultAuthenticationMiddleware`,
`tomLoggingMiddleware`), a credential helper (`extractAuthentication`), and a
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

```
TomRequestLogInfo
TomServer
```

Both classes are standalone (no Tom base class).

## Classes

### TomRequestLogInfo

Per-request logging state carried in the shelf request context.
`contextSetupMiddleware` seeds one under `contextName`; `tomLoggingMiddleware`
reads it to decide whether to emit the access-log line and mark it logged.

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
| `securityContext` | `SecurityContext?` | The TLS security context, built from the configuration when SSL is on. |
| `router` | `Router?` | The endpoint router, initialised during `start`. |
| `errorHandler` | `Response? Function(Request, Object, StackTrace)` | Maps a thrown error to a JSON error response (HTTP 500), declared `Content-Type: application/json` and marked `x-tom-error: true`; overridable via the configuration. The body is [`tomErrorEnvelope`](api_summary_little_things.md#tomerrorenvelope) — the package's single definition of the wire error shape, which this handler renders and does not define. |
| `authenticationErrorHandler` | `Response? Function(Request, Object, StackTrace)?` | Error handler applied by the outer pipeline layer; defaults to the configuration's handler, falling back to `errorHandler`. |
| `loggingMiddleware` | `Middleware` | The middleware that emits the per-request access log (`late`; from the configuration). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `start` | `void start()` | *(async)* Initialises the router, composes the pipeline, builds TLS, resolves the listen address, and binds the socket. Fire-and-forget; does not return the `HttpServer`. |

## Global Functions and Constants

| Name | Signature | Description |
| ---- | --------- | ----------- |
| `contextSetupMiddleware` | `Middleware contextSetupMiddleware(String id, [Map<String, Object>? context])` | A pass-through shelf `Middleware` that merges `context` into a copy of the request context before the inner handler runs (`id` labels it for tracing). |
| `extractAuthentication` | `(TomPrincipal?, TomClientJwtToken?) extractAuthentication(Request req)` | Extracts bearer credentials from the `Authorization` header, returning `(principal, token)`; either element is `null` when absent or unparseable (errors are swallowed). |
| `tomDefaultAuthenticationMiddleware` | `Middleware tomDefaultAuthenticationMiddleware(String id, [Map<String, Object>? context])` | The default authentication middleware: resolves the effective `TomPrincipal` and runs the inner handler in a zone exposing the request, execution context, principal, token, and a fresh `TomRequestId` — and inside a `TomTransactionManager.runInTransactionScope`, so the current transaction is per-request rather than per-isolate. A replacement must establish both. |
| `tomLoggingMiddleware` | `Middleware tomLoggingMiddleware()` | The default request-logging middleware: emits one access-log line per request, guarded by the request's `TomRequestLogInfo`. Both guards are the reason shelf's `logRequests()` is not the default — it reads no request context, so it can honour neither. |
| `noopHandler` | `Handler noopHandler(String id, int statusCode)` | A `Handler` that ignores the request and always replies with `statusCode` (`id` labels it for tracing). |
