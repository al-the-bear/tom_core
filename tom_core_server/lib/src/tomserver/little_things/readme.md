# little_things

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The server-side base exception. `TomServerException` extends the kernel's
`TomException` with the originating isolate name, a `clientThrow` flag (whether
the message may surface to the caller or must be masked as an internal error),
and automatic correlation with the request id of the current zone — the
kernel's `TomRequestId` (context module), which the server's request pipeline,
a job run and a socket message each set. Every other server module raises a
subclass of this type.

One further subclass is declared here too: `TomLoginException`, which lives next
to the base rather than beside the authentication server that consumes it, so
the 2FA subsystem can throw it without importing that server. The closed set it
classifies itself as, `TomLoginFailure`, is the kernel's: a failed
`TomAuthenticationResult` carries the same value, so a client switches on it
without depending on this package.

The module also owns `tomErrorEnvelope`, the package's single definition of what
a Tom error looks like on the wire. It is declared here because
`TomServerException` decides the one field the envelope reports conditionally,
and this is the module every other one already depends on, so both error handlers reach the builder without either reaching the other.
`tomErrorResponse` answers that envelope as the response — or, for a caller
whose `Accept` names `application/problem+json` and for an endpoint of a
`problemJson` service, the same fields as an RFC 9457 problem document.

The module also holds `TomRequestCache`, the per-request memo the framework's
authorization lookups share: the endpoint pipeline runs every request in it, a
row scope and the caller's grants and delegations are read once per request,
and any write empties it.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomServerException` | Base server error: carries `key` + `defaultUserMessage`, records `isolateName` (the isolate that **raised** it, never updated afterwards — so it says where a failure happened, not where it surfaced, and it survives an isolate hop), exposes `clientThrow` (both `final` — fixed where the error is raised), and copies the current zone's request id (`TomRequestId.value`) into `requestUuid` for correlation — unless the caller supplied one, which wins, because a caller that names a request is relaying a failure from elsewhere. It forwards the kernel's whole parameter list, including `uuid` and `serverCallError`, which every exception type in the package chains through. A response that carries a message reads it through `clientMessage(fallback)`, which returns the message only when `clientThrow` is true — reading the field directly is how an exception marked internal leaks its text. |
| `TomLoginException` | A login that cannot succeed. Adds a required `TomLoginFailure` reason to the base; the authentication services throw it and `TomAuthenticationServer` catches it. Its constructor omits `clientThrow`, so it is client-visible, unlike the rest of the authentication subsystem's exceptions. See `doc/authentication.md`. |
| `tomErrorEnvelope` | Renders any error into the wire error body. Reports `errorType` always, adds `errorKey`/`uuid`/`autoLog`/`requestUuid` for a `TomException`, `clientThrow` for a `TomServerException` and `loginFailure` for a `TomLoginException`. A field is **absent rather than null** when the error does not carry it, so its presence tells a client where the error came from. |
| `TomRequestCache` | Values a request computes once: `run` installs a fresh cache on a zone of its own (the endpoint pipeline runs every handler in it), `memo` computes a key once while it lasts, `invalidate` empties it — which the SQL data source does after every statement that changes data and the transaction manager on every rollback. |
| `tomErrorResponse` | The error response every framework error handler sends, under `x-tom-error: true`: the envelope declared `application/json`, or `tomProblemDetails` declared `application/problem+json` when `tomWantsProblemJson` finds the request asking for one (an `Accept` listing the media type with a quality above zero, or `tomProblemJsonContextKey` on the request context). A problem document is the envelope plus `type` (`urn:tom:error:<errorKey>`), `title` (`tomReasonPhrase`), `status` and `instance`; neither format carries a message. |

## Quick start

```dart
import 'package:tom_core_server/tom_core_server.dart';

void main() {
  final err = TomServerException(
    'error.order.not-found',
    'No order matched the supplied id.',
    clientThrow: true,
  );

  print(err.key);         // error.order.not-found
  print(err.clientThrow); // true  (safe to surface to the client)
}
```

See [`doc/little_things.md`](../../../../doc/little_things.md) for the isolate
attribution, the zone-based request correlation, the shape of the error
envelope and of the problem document, and `example/little_things/little_things_example.dart` for a
connection-free walkthrough that checks its own results — including that one
`on TomServerException` clause reaches every server error, and that the login
subclass arrives carrying its reason.
`test/little_things_test.dart` covers the exception and the envelope,
`test/api_versioning_test.dart` the error response and its two formats;
`test/examples_test.dart`
runs the example and `test/readme_quick_start_test.dart` runs the snippet above,
so neither can drift away from the code.
`test/server_exception_family_test.dart` holds the package to that "every": it
scans the class declarations under `lib/src/tomserver/` and fails on one that
reaches the kernel's `TomException` without passing through
`TomServerException`, so a new exception is covered the moment it is declared
rather than when someone remembers to list it.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
