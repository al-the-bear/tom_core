# Tom Core Server API Reference: Little Things Module

The base exception type for every error raised by `tom_core_server`, adding
isolate attribution and request correlation to the kernel exception — plus
`TomLoginException`, the one subclass declared beside it (its `TomLoginFailure`
reason is a kernel type) — `tomErrorEnvelope`, which renders any of them
into the wire error body, and `tomErrorResponse`, which sends that body — or the
same fields as an RFC 9457 problem document when the caller asks for one — as
the response. The correlation id the base reads out of the zone is
the kernel's `TomRequestId` (context module).

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomServerException](#tomserverexception)
- [Global Functions and Constants](#global-functions-and-constants)
  - [tomErrorEnvelope](#tomerrorenvelope)
  - [tomErrorResponse](#tomerrorresponse)

## Overview

Source: `lib/src/tomserver/little_things/server_exception.dart`,
`lib/src/tomserver/little_things/error_response.dart`.

Everything here is what the rest of the package is built on top of: the base
exception, the function that turns it into the body a client receives, and the
function that turns that body into the response. `server_exception.dart`
declares the exception and the envelope; `error_response.dart` declares the
response and its two formats.

`TomServerException` is the root of the server's exception hierarchy: every
server exception type (e.g. `TomEndpointHandlerException`, `TomCacheException`,
`MariadbMigrationException`, and `TomLoginException`) subtypes it, so a single
`on TomServerException catch (e)` clause reaches all of them. It is raised
directly at seven sites and no others — the `.named(...)` constructors of the
audit sink, the OAuth state store, the SCIM store, the delivery-report store,
the job store, the lease lock and the scheduler roll call, each refusing a data
source the registry does not hold.
Those fail at construction, where no `catch` clause is running for a subtype to
serve; everywhere else a subtype is named. Over the kernel's
`TomException` it adds two server-specific concerns: **isolate attribution** —
it captures `isolateName` at construction so a logged or serialized error
identifies the worker isolate that produced it — and **request correlation** —
when the surrounding zone carries the kernel's `TomRequestId` — set for a
request, a job run or a socket message — the constructor copies its `value`
into `TomException.requestUuid`, linking the error to the work that triggered
it. The `clientThrow` flag marks whether the exception is safe to
surface to the client.

The module declares one of those subtypes itself: `TomLoginException`, which
sits here rather than in `authentication` so the 2FA subsystem can throw it
without importing the server that catches it, together with the
`TomLoginFailure` enum it carries. Its constructor forwards the base payload
minus `clientThrow` and adds a required `reason`, so a `TomLoginException`
always carries the base default `true` — and because the field is `final`, that
is an invariant of the type rather than a starting value. Both are documented
in
[api_summary_authentication.md](api_summary_authentication.md#tomloginexception),
under the module a reader meets them in; the index files them there too, and
this summary gives them no section of its own so that the two documents cannot
drift apart.

## Class Hierarchy

```
TomException  (kernel)
    └── TomServerException
            ├── TomLoginException  (declared here; documented under Auth)
            │                      (reason: TomLoginFailure, from the kernel)
            └── …                  (every other module's exception type)
```

## Classes

### TomServerException

Base class for every exception raised by `tom_core_server`, extending the
kernel's `TomException` with isolate attribution, request correlation and the
`clientThrow` flag its `clientMessage` read honours.

- **Extends:** `TomException`

#### Constructors

```dart
TomServerException(
  String key,
  String defaultUserMessage, {
  String? uuid,
  String? requestUuid,
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool autoLog = false,
  TomServerCallError? serverCallError,
  bool clientThrow = true,
})
```

The kernel's whole parameter list is forwarded. Every exception type in the
package chains through here, so a parameter missing from this list is missing
from all of them: `uuid` is what lets an exception *reconstructed* from a wire
representation keep the identity its log line was written under, `requestUuid`
is the only route to correlation for a worker or a deserialiser that holds the
request id as a plain string rather than as a zone value, and `serverCallError`
is the kernel's slot for "this came from an HTTP call" — filled by
`TomServerSelfLoginException`.

Copies the current zone's `TomRequestId.value` into `requestUuid` **when the
caller did not supply one**. An explicit value wins: a caller that names a
request is relaying a failure from elsewhere and knows something the surrounding
zone does not, and overwriting it would re-label another request's failure with
this one's id.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `isolateName` | `final String` | The debug name of the isolate that **raised** this exception (falls back to `"unnamed isolate"`). It names the origin and is never updated: an exception raised in a pool worker and re-thrown in the main isolate still names the worker, which is the reading worth having — the workers are identical, so *which one* is what the message cannot say. It answers "where did this fail", not "where did this surface", and no hop is recorded. The name survives a `SendPort` hand-off within an isolate group. |
| `clientThrow` | `final bool` | Whether this exception is safe to propagate to the client (default `true`). Fixed at construction — a catch site that must not surface a particular failure masks it in the response it builds. Read it through `clientMessage`, not by hand: the flag binds the value, not the handler. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `clientMessage` | `String clientMessage(String maskedFallback)` | The message this exception may be shown to a client as: `defaultUserMessage` when `clientThrow` is true, `maskedFallback` when it is not. **Every response that carries a message reads it from here** — a handler reading `defaultUserMessage` directly breaks the thrower's promise by omission, and five types in the package set the flag `false` precisely because their messages describe server internals. The fallback is required and has no default: text belongs to the rendering tier, reached through a resource key. Only the *message* is masked; `key` stays on the wire for every exception. |
| `toString` | `String toString()` | *(override)* The base `TomException` string extended with `isolateName`, the `clientThrow` flag, and — only when the exception was raised inside a request — a labelled ` request: <request-id>` segment. The segment is omitted entirely when `requestUuid` is null. |

## Global Functions and Constants

| Name | Signature | Description |
| ---- | --------- | ----------- |
| `tomErrorEnvelope` | `Map<String, Object?> tomErrorEnvelope(Object error)` | Renders `error` into the framework's wire error envelope — the single definition of what a Tom error looks like on the wire, and the fields of **every** error response the package produces. |
| `tomProblemJsonMediaType` | `const String tomProblemJsonMediaType` | The media type of an RFC 9457 problem document, `application/problem+json`. |
| `tomProblemJsonContextKey` | `const String tomProblemJsonContextKey` | The request context key (`tom.problemJson`) an endpoint sets to answer its errors as problem+json whatever the request asked for. The pipeline sets it for every endpoint of a `problemJson` service. |
| `tomWantsProblemJson` | `bool tomWantsProblemJson(Request? request)` | Whether `request` is answered with a problem document: its context carries `tomProblemJsonContextKey` as `true`, or its `Accept` header lists `application/problem+json` with a quality above zero. A wildcard does not select it, and a `null` request is answered with the envelope. |
| `tomProblemDetails` | `Map<String, Object?> tomProblemDetails(Object error, int status)` | `error` as an RFC 9457 problem document answered with `status`: `type`, `title`, `status`, `instance` when the error names its request, then every envelope field as an extension member. |
| `tomErrorResponse` | `Response tomErrorResponse(Object error, {required int status, Request? request, Map<String, String> headers = const {}})` | The error response for `error` with `status`, in the format `request` asks for (`tomWantsProblemJson`), always under `x-tom-error: true`; `headers` are added to it. Every framework error response is built here. |
| `tomReasonPhrase` | `String tomReasonPhrase(int status)` | The reason phrase of the HTTP `status` (`Too Many Requests` for `429`), or `Error` for a status without a registered phrase. A problem document's `title`. |

### tomErrorEnvelope

`TomServer.errorHandler` sends the envelope as the `500` body (through
`tomErrorResponse`);
`TomUserPreferencesErrorHandler` sends the same body under a `404` or a `400`,
so a client decodes one shape rather than one per endpoint. A handler that
translates a status chooses the status, not the shape.

The body is built in layers, each reporting only what the error actually
carries:

- **`errorType`** — for every error: `error.runtimeType.toString()`, the
  concrete subtype rather than the base it was caught as.
- **`errorKey`** — for a `TomException`: the stable code a client branches on.
- **`uuid`** — for a `TomException`: the exception's own id, for matching a
  client report to a server log.
- **`autoLog`** — for a `TomException`: whether the error logged itself when
  raised.
- **`requestUuid`** — for a `TomException`: the correlated request id, or `null`
  outside a request.
- **`clientThrow`** — for a `TomServerException`: the masking flag.

A field is **absent rather than null** when the error does not carry it, so its
presence means something: a body with no `errorKey` came from something that is
not a Tom error at all, and one with no `clientThrow` came from outside the
server package — the kernel raises plain `TomException`s. Padding the shape out
with defaults would make every body look like a server error and cost a client
the distinction.

It is declared in this module because `TomServerException` decides the one
conditional field, and because this is the module every other one already
depends on — so both error handlers reach it without either reaching the other.

### tomErrorResponse

Every framework error response comes from here, so the format rule has one
author: `TomServer.errorHandler`, `TomStatusMappingErrorHandler` (and so
`TomDefaultErrorHandler`), `TomRateLimits.tooManyRequests` and the OpenAPI
document endpoint's `404` all call it.

- A request whose `Accept` lists `application/problem+json` with a quality
  above zero is answered `tomProblemDetails`, declared
  `application/problem+json`.
- So is a request served by an endpoint of a service declared with
  `problemJson: true`: the pipeline puts `tomProblemJsonContextKey` on its
  context.
- Anything else is answered `tomErrorEnvelope`, declared `application/json`.

A wildcard (`*/*`, `application/*`) does not select problem+json: a client that
has not named the format is one written against the envelope. Both bodies carry
the same fields — a problem document is the envelope with RFC 9457's members
added — and neither carries a message, so switching format reveals nothing the
other hides.

The problem document's members:

- **`type`** — `urn:tom:error:<errorKey>` for an error with a key (the key is the
  problem type a client branches on), else `about:blank`.
- **`title`** — `tomReasonPhrase(status)`.
- **`status`** — the status the response is answered with.
- **`instance`** — `urn:tom:request:<requestUuid>` when the error names the
  request it was raised in; absent otherwise.

Then every envelope field (`errorType`, `errorKey`, `uuid`, `autoLog`,
`requestUuid`, `clientThrow`, and an authentication failure's `loginFailure`)
as an extension member, so a client reads them the same way in both formats.
There is no `detail`.

```dart
// A 409 for a request that sent `Accept: application/problem+json`:
return tomErrorResponse(
  TomServerException('order.conflict', 'The order changed.'),
  status: 409,
  request: request,
);
// {"type":"urn:tom:error:order.conflict","title":"Conflict","status":409,
//  "instance":"urn:tom:request:…","errorType":"TomServerException",
//  "errorKey":"order.conflict",…}
```
