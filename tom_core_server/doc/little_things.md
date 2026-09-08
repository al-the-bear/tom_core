# Little Things Module

The server-side base exception, the correlation id it reads, and the wire shape
it is rendered into. This module contributes three types — `TomServerException`,
which every other `tom_core_server` exception extends; `TomLoginException`, the
one subclass declared here rather than beside the module that raises it; and
`TomRequestId`, the per-request id the exception constructor recovers from the
zone — plus one function, `tomErrorEnvelope`, which turns any error into the
body a client receives.

## Table of Contents

- [Overview](#overview)
- [TomRequestId](#tomrequestid)
- [TomServerException](#tomserverexception)
- [Isolate Attribution](#isolate-attribution)
- [Request Correlation](#request-correlation)
- [The clientThrow Flag](#the-clientthrow-flag)
- [The Error Envelope](#the-error-envelope)
- [Core Components](#core-components)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomRequestId` | class | Per-request v4-UUID correlation id, published into the request zone by the server's authentication middleware |
| `TomServerException` | class | Base class for all server-raised exceptions; extends the kernel's `TomException` |
| `TomLoginException` | class | A failed login, raised by the authentication services; extends `TomServerException` and adds nothing |
| `tomErrorEnvelope` | function | Renders any error into the package's wire error body — the shape every error response uses |

The kernel already provides `TomException` (UUID tracking, parameters,
auto-logging, request UUID). `TomServerException` layers two server-specific
concerns on top: it records **which isolate** produced the error and it
**correlates** the error with the active request.

## TomRequestId

```dart
final id = TomRequestId();
print(id.uuid);      // 4f8c…  a fresh v4 UUID
print(id);           // TomRequestId: 4f8c…
```

A request id is an identity and nothing else: a UUID generated in the
constructor and a `toString` that prints it. It is *produced* by the server
module — `tomDefaultAuthenticationMiddleware` puts a fresh one into `zoneValues`
for every incoming request — and *consumed* here, by the `TomServerException`
constructor, as well as by the endpoints pipeline (which logs it) and the audit
trail (which stores it on every entry).

It is declared in this module rather than beside the middleware that seeds it
because the dependency arrow has to point this way. `little_things` holds the
base class that twenty-seven types across every other module extend, so it is
the most depended-upon module in the package; `server` is the largest and most
concrete. Declaring the id beside its producer would have made the first import
the second, which is the cycle this placement avoids. The same move takes the
audit trail off the server module entirely — `TomRequestId` was the only thing
it imported from there.

## TomServerException

```dart
throw TomServerException(
  'PAYMENT_FAILED',
  'The payment could not be processed',
  clientThrow: false, // internal detail — do not surface to the caller
);
```

Because every server exception subtypes `TomServerException`, a single catch
clause reaches all of them:

```dart
try {
  await handleRequest();
} on TomServerException catch (e) {
  log.error('${e.isolateName}: ${e.key} (req ${e.requestUuid})');
  if (e.clientThrow) respondWith(e.defaultUserMessage);
  else respondWith('Internal error');
}
```

That "every" is enforced rather than merely asserted.
`test/server_exception_family_test.dart` reads every class declaration under
`lib/src/tomserver/`, walks each `extends` chain, and fails on any class that
reaches the kernel's `TomException` without passing through
`TomServerException`. It is a source scan rather than a runtime check on
purpose: a runtime check can only examine the types someone remembered to list,
which is precisely the property that fails. A new exception class is therefore
covered the moment it is written, and a class that leaves the family names its
own file in the failure.

Leaving the family is worth catching because three things are built on the
claim: the endpoints pipeline classifies a failure by catching
`TomServerException`, so a type outside it reaches the client unclassified;
`tomErrorEnvelope` writes `clientThrow` only for a member, so a non-member
cannot say whether its message may be shown; and the isolate and request
attribution below is added by the base constructor, so a non-member arrives
naming neither the worker that raised it nor the request that caused it.

## Isolate Attribution

Server work is spread across an isolate pool, so the bare error message alone
does not tell you which worker failed. `TomServerException` captures
`Isolate.current.debugName` into `isolateName` at construction time (falling
back to `"unnamed isolate"` when the isolate has no debug name), and appends it
to `toString()`. This makes a logged error self-identifying without the call
site having to record the isolate explicitly.

## Request Correlation

`tomDefaultAuthenticationMiddleware` sets a `TomRequestId` in the zone for the
lifetime of a request. When a `TomServerException` is constructed inside that
zone, its
constructor reads the id via `getFromCurrentZone<TomRequestId>()` and copies the
UUID into the inherited `requestUuid` field. The error is therefore linked to
the request that triggered it without any code threading the id through the call
stack. Outside a request zone (e.g. during startup) `requestUuid` is simply left
unset.

`toString()` renders the correlation as a trailing `request: <uuid>` segment,
and omits that segment altogether when the exception was raised outside a
request:

```text
<uuid>-<request-uuid>, TomServerException: K, m, ... main client-throw: true request: <request-uuid>
<uuid>-null, TomServerException: K, m, ... main client-throw: true
```

The label matters more than it looks. The base `TomException` already carries
the id, but only inside the composite leading token
`<exception-uuid>-<request-uuid>` — and because v4 UUIDs contain hyphens
themselves, that token cannot be split back into its two ids by eye or by a
simple pattern. The labelled copy is what makes the correlation greppable.

## The clientThrow Flag

`clientThrow` (default `true`) marks whether the exception is safe to surface to
the caller. The endpoints pipeline may relay the user message of a
`clientThrow: true` exception, while a `clientThrow: false` exception should be
masked behind a generic error response — use it for internal failures whose
detail must not leak.

`TomLoginException` does not offer the choice at construction: its constructor
forwards the rest of the payload but not `clientThrow`, so every
`TomLoginException` is client-visible. Omitting the parameter is the common
shape — fifteen of the package's twenty-eight subtypes inherit the `true`
default the same way — but the neighbourhood makes it a decision rather than an
omission. Every other exception the authentication subsystem raises is hidden:
`Tom2FAException` and `TomServerSelfLoginException` hard-wire
`clientThrow: false`, and `TomOAuthException` re-defaults it to `false`. The
login failure is the exception whose message is written for the person who
mistyped a password, so it is the one that may reach them.

Both `clientThrow` and `isolateName` are `final`, so what the constructor fixes
is the value and not merely a default. That is deliberate: an exception is a
value describing something that has already happened, and both fields record a
fact about the moment it was raised — which worker produced it, and whether the
party that wrote the message intended it for a client. A catch site that decides
a particular failure must not leave the server masks it in the response it
builds, rather than rewriting the error's account of itself. On this path the
question rarely arises anyway, because `TomAuthenticationServer` catches the
exception and turns its `key` into a failed `TomAuthenticationResult` rather
than letting it reach the pipeline that reads the flag.

## The Error Envelope

`tomErrorEnvelope(error)` is the single definition of what a Tom error looks
like on the wire. Every error response body the package produces comes from
here: `TomServer.errorHandler` sends it as the `500` body, and
`TomUserPreferencesErrorHandler` sends the same body under a `404` or a `400`,
so a client decodes one shape rather than one shape per endpoint.

```dart
tomErrorEnvelope(TomServerException('order.not-found', 'No such order.'));
// {
//   errorType:   'TomServerException',
//   errorKey:    'order.not-found',
//   uuid:        '…',
//   autoLog:     false,
//   requestUuid: '…',   // or null outside a request
//   clientThrow: true,
// }
```

The body is built in layers, each reporting only what the error actually
carries. `errorType` is unconditional — every failure has a runtime type, and a
client that recognises nothing else can still log something specific.
`errorKey`, `uuid`, `autoLog` and `requestUuid` are added for a `TomException`,
which is what a client branches on. `clientThrow` is added for a
`TomServerException`, and only there.

A field is **absent rather than null** when the error does not carry it, so its
presence means something. A body with no `errorKey` came from something that is
not a Tom error at all; a body with no `clientThrow` came from outside this
package — the kernel raises plain `TomException`s, so a validation refusal
relayed from there is distinguishable from a failure raised on the server side.
Padding the shape out with defaults would make every body look like a server
error and cost a client that distinction.

The function is declared here for the same reason `TomRequestId` is.
`TomServerException` decides the one conditional field, and this is the module
every other one already depends on — so both error handlers reach the builder
without either reaching the other.

## Core Components

- **`TomRequestId`** — a per-request v4 UUID and nothing else. Created once per
  request by `tomDefaultAuthenticationMiddleware` and published into the request
  zone; recovered with `getFromCurrentZone<TomRequestId>()` by the exception
  base, the endpoints pipeline and `TomAuditTrail.currentRequestId`.
- **`TomServerException`** — the base server exception. Adds `isolateName`
  (originating worker), `clientThrow` (client-safe flag), and zone-based
  `requestUuid` population to the kernel's `TomException`.
- **`TomLoginException`** — a login that cannot succeed: unknown client or user,
  invalid credentials, no enrolled second factor, an expired challenge. Raised
  by `TomAuthenticationService`, `Tom2FAService` and their helpers, and caught
  by `TomAuthenticationServer`, which turns its `key` into a failed
  `TomAuthenticationResult`. It adds **nothing** over the base — no fields, no
  methods, no behaviour; it exists so that the two sides can name the same
  failure. See `doc/authentication.md` for the login flow it belongs to.
- **`tomErrorEnvelope`** — renders any error into the wire error body, reporting
  `errorType` always, the `TomException` fields for a Tom error, and
  `clientThrow` for a server one. Used by `TomServer.errorHandler` and
  `TomUserPreferencesErrorHandler`; a handler that translates a status chooses
  the status and not the shape.

`TomLoginException` is declared here, next to the base class, rather than beside
the authentication server that consumes it, so that the 2FA subsystem can throw
it without importing that server. The cost of that placement is this guide: a
reader looking up the module finds a type whose whole meaning lives in another
one.

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:isolate` | dart | `server_exception.dart` | `Isolate.current` for the worker's debug name |
| `tom_core_kernel` | package | `server_exception.dart` | `TomException` (the base class), `getFromCurrentZone` |
| `uuid` | package | `request_id.dart` | v4 UUID generation for `TomRequestId` |

The module imports no other module of this package, which is the point: it sits
at the bottom of the dependency graph and everything else may depend on it.
