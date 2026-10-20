# server

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The HTTP server entry point. `TomServer` is constructed from a
`TomBaseServerConfiguration`, builds its endpoint router during `start`, and
binds the listener. Each request gets a `TomRequestLogInfo` record, a
`TomRequestId` and a W3C trace context — minted (or, for the trace, continued
from the caller's `traceparent`) by `tomRequestContextMiddleware` before
anything else runs, so every log line, exception and audit entry of the request
correlates, and echoed as the `X-Request-Id` and `traceparent` response headers
— and its own current transaction, because the authentication middleware runs the request inside a
[`TomTransactionManager`](../transactions/readme.md) scope; without it, requests
interleaving in one isolate would share whichever transaction the manager last
made current. The id type is declared in
[`little_things`](../little_things/readme.md), beside the exception base that
consumes it.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomServer` | The server: `TomServer(configuration)`; builds the `TomEndpointRouting` and starts listening. |
| `TomRequestLogInfo` | Captured per-request log metadata, including the matched endpoint's `route` pattern the request metrics are labelled with. |
| `tomRequestLogInfoMiddleware` | Seeds a new `TomRequestLogInfo` into every request's context; `start` installs it outermost. |
| `tomRequestContextMiddleware` · `tomRequestIdHeader` | Mints the request id, continues or starts the trace, runs the rest of the pipeline in a zone carrying both, and answers with `X-Request-Id` and `traceparent`; registers the `request_id` field of structured log lines. |
| `TomEndpointCredentials` | The path prefixes whose `Authorization` header belongs to the endpoint rather than the framework — the SCIM endpoints, whose identity provider presents a static secret. `extractAuthentication` leaves such a header unread and reports `TomCredentialOutcome.endpointCredential`; the endpoint checks it. |

## Quick start

```dart
import 'package:tom_core_server/tom_core_server.dart';

void main() {
  // `configuration` is your TomBaseServerConfiguration subclass (it supplies
  // the bind address/port, TLS, datasources, and endpoint registrations).
  final server = TomServer(configuration);
  server.start();

  // The server is now listening; each request carries a TomRequestId UUID.
}
```

> **A long-running service, and a fragment.** `configuration` stands for your
> own `TomBaseServerConfiguration` subclass, so this does not compile as
> written; and once it does, it is meant *not* to return — the bound listener
> holds the isolate open for as long as the deployment serves. That is the one
> module here where a program that never terminates is the correct one, which
> is why the other quick starts stop their timers and close their sockets and
> this one does not.

`start()` does one thing before it binds anything: when the configuration
carries a service credential, the deployment logs *itself* in
([`TomServerSelfLogin`](../authentication/readme.md)) and installs the
`TomServerPrincipal` that caps every user's grants at `min(user, server)`.
Binding first would serve requests uncapped for as long as the login took, so a
configured deployment that cannot log in has the error rethrown and **never
binds the socket** — visible as an unhandled asynchronous error at boot, since
`start()` is fire-and-forget. A deployment that configures no credential skips
the login and is unaffected.

**Logs and readiness.** `start` applies `logFormat` — `json` writes one JSON
object per line carrying `trace_id`, `span_id`, `request_id` and `tenant`
(`TomServer.applyLogFormat`) — and, with `frameworkReadiness` on (the default),
answers `GET /ready` from the framework's own checks unless the application
installed a readiness analyzer — see
[`doc/healthcheck.md`](../../../../doc/healthcheck.md).

**Metrics.** `start` places the metrics module's scrape endpoint (when
`metricsEndpoint` is on) and request series at the outer edge of the pipeline,
and pushes over OTLP through `TomServer.metricsExporter` when `otlpEndpoint` is
set — see [`doc/metrics.md`](../../../../doc/metrics.md).

See [`doc/server.md`](../../../../doc/server.md) for the boot sequence, the
middleware chain and the shutdown path, and
`example/server/server_example.dart` for a walkthrough of the surface a
deployment configures — it stops short of binding a socket, so unlike the
fragment above it is a program that runs and terminates.
`test/server_test.dart` covers the module and
`test/server_self_login_test.dart` the credentialled boot described above,
replacing the one JSON POST rather than running an auth server;
`test/scim_test.dart` reads a claimed path as `endpointCredential`;
`test/structured_logs_readiness_test.dart` covers the correlation ids and the
log format;
`test/examples_test.dart` runs the example.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
