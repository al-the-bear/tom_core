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
| `tomRequestLogInfoMiddleware` | Seeds a new `TomRequestLogInfo` into every request's context; `start` installs it directly inside the shutdown gate. |
| `tomRequestContextMiddleware` · `tomRequestIdHeader` | Mints the request id, continues or starts the trace, runs the rest of the pipeline in a zone carrying both, and answers with `X-Request-Id` and `traceparent`; registers the `request_id` field of structured log lines. |
| `TomGracefulShutdown` · `tomProbePaths` | What the server does between SIGTERM and exiting: readiness off, the listener closed, new requests refused with `503` while the probe paths pass, the requests and scheduled runs in flight finished within the grace period, leases released and pools closed. `TomServer.gracefulShutdown` holds the server's; `TomServer.shutdown()` runs it without a signal. |
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
binds the socket** — `start()`'s future rejects with the error. A deployment that configures no credential skips
the login and is unaffected.

**Logs and readiness.** `start` applies `logFormat` — `json` writes one JSON
object per line carrying `trace_id`, `span_id`, `request_id` and `tenant`
(`TomServer.applyLogFormat`) — and, with `frameworkReadiness` on (the default),
answers `GET /ready` from the framework's own checks unless the application
installed a readiness analyzer — see
[`doc/healthcheck.md`](../../../../doc/healthcheck.md).

**Outgoing HTTP calls.** `start` applies the `httpClient` key of the
configuration resources (`TomServer.configureHttpClients`,
`TomServer.httpClientConfigurationKey`) to the kernel's `TomHttpResilience`:
the timeout, retry, circuit-breaker and bulkhead policies every framework call
to another service runs under, overall and per destination. A value of the
wrong shape stops the start with `http.client.config.invalid` — see
[`doc/configuration.md`](../../../../doc/configuration.md#outgoing-http-calls).

**Idempotency keys.** `start` applies the `idempotency` key of the
configuration resources (`TomServer.configureIdempotency`,
`TomServer.idempotencyConfigurationKey`) right after: a `datasource` keeps the
records of `@TomIdempotent` endpoints in a `TomSqlIdempotencyStore` shared by
every instance, and `retentionMinutes` / `inProgressTimeoutSeconds` set how
long a response is replayed and when an abandoned claim is taken over. Without
the key the records stay in memory, on one process — see
[`doc/configuration.md`](../../../../doc/configuration.md#idempotency-keys).

**Field-level encryption.** `start` then awaits the `fieldEncryption` key
(`TomServer.configureFieldEncryption`, `TomFieldEncryption.configurationKey`):
the data-key table and the key-encryption keys `@TomEncrypted` columns are
encrypted under, from which it installs the keyring before the deployment's own
login and before anything reads an entity. Without the key no keyring is
installed, and an encrypted column fails its first write with
`field_encryption.not_configured` — see
[`doc/configuration.md`](../../../../doc/configuration.md#field-level-encryption).

**Graceful shutdown.** `start` puts the shutdown gate outermost in the
pipeline and registers `TomServer.gracefulShutdown` for SIGTERM and SIGINT: on
either signal `/ready` turns to `503`, the listener closes, a new request is
refused with `503` and `Connection: close`, the requests and scheduled runs in
flight get `shutdownGracePeriodSeconds` to finish, the outboxes and schedulers
release their leases, the data sources close their pools, and the process exits
(`exitOnShutdownSignal`) — see
[`doc/server.md`](../../../../doc/server.md#graceful-shutdown), with the
Kubernetes settings.

**Metrics.** `start` places the metrics module's scrape endpoint (when
`metricsEndpoint` is on) and request series at the outer edge of the pipeline,
and pushes over OTLP through `TomServer.metricsExporter` when `otlpEndpoint` is
set — see [`doc/metrics.md`](../../../../doc/metrics.md).

See [`doc/server.md`](../../../../doc/server.md) for the boot sequence, the
middleware chain and the shutdown path, and
`example/server/server_example.dart` for a walkthrough of the surface a
deployment configures — it stops short of binding a socket, so unlike the
fragment above it is a program that runs and terminates;
`example/server/graceful_shutdown_example.dart` runs a graceful shutdown step
by step without a socket.
`test/server_test.dart` covers the module and
`test/server_self_login_test.dart` the credentialled boot described above,
replacing the one JSON POST rather than running an auth server;
`test/scim_test.dart` reads a claimed path as `endpointCredential`;
`test/structured_logs_readiness_test.dart` covers the correlation ids and the
log format; `test/graceful_shutdown_test.dart` the graceful shutdown, with a real
SIGTERM sent to a server process;
`test/examples_test.dart` runs the example.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
