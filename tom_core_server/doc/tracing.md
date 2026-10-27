# Tracing Module

How a Tom server records the spans of a trace and sends them to a tracing
backend. The spans are opened through `tom_core_kernel`'s tracing seam,
`TomTracing` — a request, an SQL statement, a transaction, an outgoing HTTP
call, a job run, an outbox send and delivery — and recorded by whatever
`TomTracer` is installed (see the kernel's
[context guide](../../tom_core_kernel/doc/context/context.md#tracing) and
[API summary](../../tom_core_kernel/doc/api/api_summary_context.md)). This
module is the tracer a server installs: `TomOtelTracer`, over the OpenTelemetry
SDK, exporting OTLP/HTTP to the receiver the metrics are pushed to.

**Tracing is off by default, and off costs nothing.** With no tracer installed
every instrumented call asks whether one is installed and runs its work
unchanged: no span object, no zone, no attribute map. The trace context —
`traceparent` in and out, the `trace_id` and `span_id` of every log line, the
request id — is carried either way, since it does not depend on a tracer.

## Table of Contents

- [Overview](#overview)
- [Configuration](#configuration)
- [What Is Traced](#what-is-traced)
  - [Requests](#requests)
  - [SQL statements](#sql-statements)
  - [Transactions](#transactions)
  - [Outgoing HTTP calls](#outgoing-http-calls)
  - [Job runs](#job-runs)
  - [The outbox](#the-outbox)
- [Bound Values Are Never Recorded](#bound-values-are-never-recorded)
- [Sampling](#sampling)
- [Propagation](#propagation)
  - [Across HTTP calls](#across-http-calls)
  - [Through the outbox](#through-the-outbox)
- [Export](#export)
  - [The export is not traced](#the-export-is-not-traced)
  - [The final export](#the-final-export)
- [Testing](#testing)
- [Running Against a Collector](#running-against-a-collector)
- [Failure Keys](#failure-keys)
- [Not Yet Implemented](#not-yet-implemented)
- [Verification](#verification)
- [Core Components](#core-components)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomTracingException` | class | Tracing cannot be set up as configured: no endpoint, or a sample percentage outside 0 to 100 |
| `TomOtelTracer` | class | The kernel's `TomTracer` over the OpenTelemetry SDK; exports spans over OTLP/HTTP and samples parent-first |
| `TomUntracedClient` | class | The HTTP client the exporter sends through: never traced, and closing only once the exports in flight are answered |
| `TomInMemorySpanExporter` | class | A span exporter keeping exported spans in memory, for tests |

The module is one file, `otel_tracer.dart`, and the only place in the package
that imports `package:opentelemetry`. Every other module opens its spans
through the kernel's `TomTracing`, so the SDK could be replaced here alone.

`TomServer.start` installs the tracer when `tracing` is on —
`TomServer.configureTracing`, called right after `configureHttpClients`, so the
start's own outgoing calls and SQL are traced too. It keeps it as
`TomServer.tracer` and registers it with the shutdown cleanup. A tracer the
application installed itself with `TomTracing.install` before `start` is kept,
and `tracer` stays `null`. See [server.md](server.md#tracing).

## Configuration

Two keys of `TomBaseServerConfiguration` switch tracing on; the spans go to the
receiver and with the headers the metrics export uses (see
[configuration.md](configuration.md#publishing-metrics)):

| Key | Environment | Type | Default | Effect |
| --- | ----------- | ---- | ------- | ------ |
| `tracing` | `TRACING` | `bool` | `false` | Record spans and export them to `otlpEndpoint`. Refused without an endpoint |
| `tracingSamplePercent` | `TRACING_SAMPLE_PERCENT` | `int` | `100` | The percentage of new traces recorded, 0 to 100 |
| `otlpEndpoint` | `OTLP_ENDPOINT` | `String` | empty | The OTLP/HTTP receiver's base URL; spans are posted to `<otlpEndpoint>/v1/traces` |
| `otlpHeaders` | `OTLP_HEADERS` | `String` | empty | Headers of every export, as `key=value,key=value`; may carry a credential |

```yaml
# assets/config-resources_default.yaml
tracing: true
tracingSamplePercent: 20
otlpEndpoint: "http://otel-collector:4318"
otlpHeaders: "x-tenant=ops"
```

The process is described by the resource attribute `service.name`: the
configured `appId`, or `tom_server` without one. `TomOtelTracer.fromConfiguration`
builds the tracer and answers `null` when `tracing` is off.

## What Is Traced

Every span the framework opens, by the module that opens it. The attribute
names follow the OpenTelemetry semantic conventions where one exists; the
framework's own are prefixed `tom.`. A span whose work throws records the error
and is marked failed.

**A statement or a transaction is recorded only as a step of traced work.**
Their spans are started with `childOnly` (`TomTracing.start`): inside a request,
a job run or another span they are recorded as described below; outside any
trace — a scheduler polling its job store, which runs in no request and no job
run — they record nothing, so the backend is not filled with one-span traces of
background housekeeping.

| Span | Span kind | Opened by | Attributes |
| ---- | --------- | --------- | ---------- |
| `<METHOD> <route>` | server | `tomRequestContextMiddleware` | `http.request.method`, `url.path`, `url.scheme`, `network.protocol.version`, `http.route`, `http.response.status_code` |
| `SELECT`, `INSERT`, … | client | `TomSqlDatasource` | `db.system.name`, `db.operation.name`, `db.query.text`, `tom.datasource` |
| `transaction` | internal | `TomTransaction` | `tom.transaction.id`, `tom.transaction.read_only`, `tom.transaction.outcome`, `tom.transaction.participants` |
| `GET`, `POST`, … | client | `TomResilientClient` (kernel) | `http.request.method`, `url.full`, `server.address`, `server.port`, `http.response.status_code` |
| `job <jobName>` | internal | `TomJobRunCommand` (kernel) | `tom.job.name`, `tom.job.run_id` |
| `outbox send` | producer | `TomMessageOutbox.send` | `messaging.system`, `messaging.operation.type`, `messaging.destination.name`, `messaging.message.id` |
| `outbox deliver` | consumer | the outbox's delivery job | the four above, and `tom.job.run_id` |

### Requests

`tomRequestContextMiddleware` opens a `server` span for every request it serves,
continuing the caller's `traceparent` (and `tracestate`) or starting a trace.
The span is named after the method and renamed `<METHOD> <route>` —
`GET /tasks/<id>`, the route pattern and never the concrete path — once the
endpoint pipeline has recorded the matched route in `TomRequestLogInfo.route`;
a request no endpoint matched keeps the bare method. `url.path` is the concrete
path, `http.route` the pattern, and `http.response.status_code` the status
answered. A `5xx` marks the span failed (`HTTP <status>`). A metrics scrape is
answered above the middleware and is not traced.

The span is the request's trace context: the response's `traceparent` header
is the server span, every log line written for the request carries its
`span_id`, and the spans the request's work opens are its children.

### SQL statements

Every statement `TomSqlDatasource` runs on a connection — a query, a command, a
prepared statement's execution, the preparation itself — is a `client` span,
following the OpenTelemetry database conventions:

| Attribute | Value |
| --------- | ----- |
| `db.system.name` | `TomSqlDatasource.dbSystemName`: `mariadb` or `postgresql` |
| `db.operation.name` | The statement's first keyword, upper-cased — `SELECT`, `INSERT`, `WITH` |
| `db.query.text` | The statement as written, with its placeholders — see [Bound Values Are Never Recorded](#bound-values-are-never-recorded) |
| `tom.datasource` | The data source's registered name (`<base>@<tenant>` for a tenant's own pool) |

The span is named after the first keyword; a statement opening with none, or a
connection used without a statement (`withDriverConnection`), is named after
the operation — `query`, `command`, `prepared`, `prepare`, `driver`. A
statement run outside any trace records no span. It covers
the statement on its connection, not the wait for the connection (that is the
`tom_db_pool_acquire_duration_seconds` histogram, see
[metrics.md](metrics.md#data-sources)). A statement served by a read replica is
a span of the replica's data source. A failing statement is a failed span. See
[datasources.md](datasources.md#tracing).

### Transactions

A `TomTransaction` is a span named `transaction` from its start to its
conclusion, exposed as `TomTransaction.span` — `null` with tracing off, and
for a transaction opened outside traced work, which records no span. Work
opened by `TomTransactionManager.runInTransaction` or a transactional endpoint
runs inside it (`TomTransaction.runInSpan`), so its statements are the span's
children. The span ends with the conclusion and carries its outcome
(`tom.transaction.outcome`: `committed`, `partiallyCommitted`, `rolledBack`,
`rolledBackWithFailures`) and the number of participants. An outcome that left
work outstanding — `partiallyCommitted` or `rolledBackWithFailures` — marks it
failed. See [transactions.md](transactions.md#tracing).

### Outgoing HTTP calls

Every call through the kernel's `TomResilientClient` — which every
`TomServerChannel` call, a webhook delivery and an identity provider's token
exchange go through — is a `client` span named after its method, covering all
its attempts. `url.full` carries scheme, host, port and path, never the query or
the user info, which may carry credentials. A `5xx` answer marks it failed, as
does a call that got no answer. See the kernel's
[HTTP connection guide](../../tom_core_kernel/doc/http_connection/http_connection.md#the-client-span).

### Job runs

Every attempt of a scheduled job is the first span of a trace of its own,
`job <jobName>`, with `tom.job.name` and `tom.job.run_id`; the trace id is the
attempt's request id, so the trace its log lines name is the one its spans are
exported under. See the kernel's
[scheduling guide](../../tom_core_kernel/doc/scheduling/scheduling.md#the-ids-a-run-logs-under).

### The outbox

`TomMessageOutbox.send` is a `producer` span, `outbox send`, whose context is
written into the queued message's headers (see
[Through the outbox](#through-the-outbox)). The delivery — a job run of the
outbox — is a `consumer` span, `outbox deliver`, continuing that header, with
the job run's id as `tom.job.run_id`; a message queued outside any trace is
delivered as a step of the job run's own trace. `messaging.system` is
`tom_outbox`, `messaging.operation.type` is `send` or `process`,
`messaging.destination.name` the outbox's job name, `messaging.message.id` the
message id. See [messaging.md](messaging.md#tracing).

## Bound Values Are Never Recorded

`db.query.text` is the statement **as written** — with its `:name` or `?`
placeholders — and never a bound value. A parameter may hold a password hash, a
national id or a token, and a span is sent to a third-party backend, kept for
weeks and readable by everyone with access to it. No attribute the framework
sets carries a bound value; `test/tracing_db_test.dart` binds a marker value and
checks that it appears in no attribute of any exported span.

The rule covers what the framework binds. A value an application writes into
the SQL text itself, instead of binding it, is part of the statement and is
recorded as written — one more reason to bind.

## Sampling

`TomOtelTracer` samples **parent-first**:

- **A span continuing a parent is sampled as its parent is.** For a request
  from a traced caller the `sampled` flag of its `traceparent` decides, whatever
  `tracingSamplePercent` says, so a trace is either whole or absent across the
  services it touches.
- **A new trace is sampled with the probability `tracingSamplePercent`**,
  decided from the random low bytes of its trace id. Every process deciding for
  the same trace id decides alike.

An unsampled span is still made: its context is propagated, flagged unsampled,
so a callee does not record its part of a trace the caller dropped. It is not
exported.

## Propagation

### Across HTTP calls

A request's server span continues an incoming `traceparent` and keeps its
`tracestate`; the response answers with the server span's `traceparent`. An
outgoing call through `TomResilientClient` sends its own client span's position
(`TomResilientClient.propagateTrace(request, span: ...)`), so the callee's server
span is a child of the call that reached it — one tree across both processes.
A request that names a `traceparent` of its own keeps it.

### Through the outbox

A message is delivered after the request that queued it has been answered,
possibly by another node. So `TomMessageOutbox.send` writes its producer span's
`traceparent` (and `tracestate`) into `TomMessage.headers`, where it is stored
with the message; the delivery continues it however much later it runs. An email
carries the header to whoever reads its source.

`TomWebhookTransport` drops `traceparent` and `tracestate` from the message's
headers when it posts the message: the webhook call propagates its own client
span, so the receiver's span is a child of the call, not of the producer.

## Export

`TomOtelTracer.otlp` hands ended spans to the SDK's `BatchSpanProcessor`, which
sends them every five seconds, or when a batch is full, to
`<endpoint>/v1/traces` as an OTLP `ExportTraceServiceRequest` in protobuf, with
the configured headers. The URL is `TomOtlpHttpTransport.urlOf('traces')`, the
same rule the metrics export follows, so one `otlpEndpoint` and one
`otlpHeaders` serve both signals.

### The export is not traced

The exporter sends through a `TomUntracedClient` over the kernel's
`TomResilientClient` — the receiver's circuit breaker applies — and every call
it makes runs `TomTracing.untraced`. Without that, posting a batch would be an
outgoing HTTP call, a client span of its own, exported in the next batch, which
would contain another export's span, without end. The metrics push runs
untraced for the same reason (see [metrics.md](metrics.md#otlp-export)).

### The final export

The shutdown cleanup closes the tracer (`close`, which is `shutdown`): the
processors export what they hold and stop. `flush` and `shutdown` complete only
when the export they started has been answered — `TomUntracedClient.idle` — and
`TomUntracedClient.close` lets the calls in flight finish before closing the
inner client, because the SDK's exporter starts its last export and closes its
client in the same breath. A client closed at once would drop the spans of a
server's last seconds.

## Testing

Two in-memory tracers record without a collector:

- **`TomRecordingTracer`** (kernel) keeps `TomRecordedSpan`s: names, kinds,
  attributes, errors. It needs no SDK and is what the kernel's own tests use.
- **`TomInMemorySpanExporter`** sits behind a `TomOtelTracer` with the SDK's
  `SimpleSpanProcessor`, so a test sees the spans exactly as the OTLP exporter
  would receive them — the SDK's ids, kinds, status and sampling.

```dart
final exported = TomInMemorySpanExporter();
TomTracing.install(
  TomOtelTracer(processors: [otel_sdk.SimpleSpanProcessor(exported)]),
);
addTearDown(() => TomTracing.install(null));

// ... serve a request through the pipeline ...

final request = exported.named('GET /tasks/<id>').single;
final children = exported.childrenOf(request);
expect(
  TomInMemorySpanExporter.attributeOf(request, 'http.response.status_code'),
  200,
);
```

`TomTracing.install` is process-wide state of the isolate: install in a test's
set-up and uninstall in its tear-down, as `test/tracing_test.dart` does.

## Running Against a Collector

`tom_core_samples/advanced_deploy/otel/` holds a local OpenTelemetry Collector
for the samples: `docker-compose.yaml` starts it on `127.0.0.1:4318` and
`collector.yaml` writes every trace export to `out/traces.json` and every
metrics export to `out/metrics.json`, one export per line. Start a sample
server against it with

```bash
docker compose -f advanced_deploy/otel/docker-compose.yaml up -d
cd advanced_app_server
TRACING=true OTLP_ENDPOINT=http://127.0.0.1:4318 \
  dart run bin/app_server_start.dart env=dev
```

and every request appears in `out/traces.json` within five seconds. Replace the
collector's file exporters with a backend's — Jaeger, Tempo, a vendor — to look
at the traces rather than read them.

In the `tom_core_samples` package,
`advanced_client_core/tool/run_cross_tier_integration.sh --trace` starts that
collector, runs both sample servers with tracing on and checks that each
exported its routed request spans and the app server its SQL spans inside them.

## Failure Keys

| Key | Raised by | Meaning |
| --- | --------- | ------- |
| `tracing.config.no_endpoint` | `TomOtelTracer.fromConfiguration`, and so `TomServer.start` | `tracing` is on and `otlpEndpoint` is empty. |
| `tracing.config.invalid_sample_percent` | `TomOtelTracer`, `TomOtelTracer.fromConfiguration` | A sample percentage outside 0 to 100. Parameter `samplePercent`. |
| `otlp.config.invalid_headers` | `TomOtlpHttpTransport.parseHeaders`, read by `fromConfiguration` | An `otlpHeaders` entry without `=`. |

`TomTracingException` extends `TomServerException` with `clientThrow: false`:
it is the server's own failure, never a client's answer. Both keys stop
`TomServer.start` before the socket is bound.

## Not Yet Implemented

- **No spans in worker isolates.** The installed tracer is state of the isolate
  that installed it. A job dispatched to a worker-pool isolate runs there with
  no tracer, so its attempt and everything it does are not traced; its log
  lines still carry the attempt's trace and request id.
  <!-- unpinned: decision — a tracer is per-isolate state, like the metrics registry -->
- **No WebSocket message spans.** A socket's upgrade request is a server span
  like any request; the messages exchanged over the socket open none.
  <!-- unpinned: absence — the socket serving loop opens no span -->
- **No span links.** A span has one parent. A delivery continues the producer
  that queued it and is not linked to the job run that delivered it; the
  `tom.job.run_id` attribute names that run instead.
  <!-- unpinned: absence — TomTracer.startSpan takes no links -->
- **No log export.** Log lines carry `trace_id` and `span_id`, so a backend
  can join them to the spans, but they are not sent over OTLP; they go wherever
  the log output writes them.
  <!-- unpinned: absence — no OTLP log exporter exists -->

## Verification

`test/tracing_test.dart` covers the module without a database: tracing off
unless configured, refused without an endpoint and for a sample percentage out
of range, and a configured tracer exporting to the endpoint's `v1/traces`; the
tracer's spans carrying the exported ids, attributes keeping their types, a span
continuing a caller following the caller's sampling, new traces sampled at the
configured percentage, closing the export client letting the export in flight
finish, and the exporter's own calls not traced; a request as a server span
continuing the caller and named after its route, a `5xx` as a failed span, and a
request without a tracer answered unchanged, with a trace; a transaction as a
span around its work ending with its outcome, and a failure recorded once on
rollback; an outbox message carrying the trace that queued it to its delivery,
and queued unchanged without a tracer; and an outgoing call to a Tom server
continued by the callee's server span.

`test/tracing_db_test.dart`, tagged `db`, runs a traced request against the
database the DB suites run against — MariaDB or PostgreSQL: the exported tree of
request, transaction, statement and outgoing call, the statement's
`db.system.name`, `db.operation.name` and `tom.datasource`, no bound value in
any attribute, and a failing statement as a failed span.
`tool/run_db_tests.sh` (MariaDB) or `tool/run_db_tests_postgres.sh`
(PostgreSQL) starts a database for it.

`test/tracing_otel_test.dart`, tagged `otel`, has the export read by its
consumer: an OpenTelemetry Collector receives a request's spans with their
tree. It skips unless the collector is available; `tool/run_otel_tests.sh`
starts it with `tool/otel/collector.yaml`, whose traces pipeline writes
`/out/traces.json`, runs the suite with the metrics one and treats a run in
which every test skipped as a failure.

The spans the kernel opens — a job run, an outgoing call — and
`TomRecordingTracer` are covered by the kernel's `test/tracing_test.dart`.

```bash
dart run example/tracing/tracing_example.dart
tool/run_otel_tests.sh
```

`example/tracing/tracing_example.dart` walks the module without a server or a
database: a request continuing its caller's trace as a server span named after
its route, its transaction and outgoing call as children, the callee continuing
the call's span, the tree posted over OTLP to an in-process receiver's
`/v1/traces`, and tracing off recording nothing while the trace context still
flows. Every step checks its own result, and `test/examples_test.dart` runs it.

## Core Components

- **`TomOtelTracer`** — `samplePercent`; the constructor over span processors,
  `otlp`, `fromConfiguration`; `startSpan`, `flush`, `shutdown`, `close`.
- **`TomUntracedClient`** — `idle`, `send`, and a `close` that waits for the
  calls in flight.
- **`TomInMemorySpanExporter`** — `spans`, `named`, `childrenOf`,
  `attributeOf`.
- **`TomTracingException`** — every failure this module raises.

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | `otel_tracer.dart` | `Completer` and `StreamTransformer`, the in-flight count of `TomUntracedClient` |
| `dart:math` | dart | `otel_tracer.dart` | `pow`, the sampling threshold |
| `http` | package | `otel_tracer.dart` | `BaseClient`, `Client` and `StreamedResponse`, the export client |
| `opentelemetry` | package | `otel_tracer.dart` | The SDK: `TracerProviderBase`, `BatchSpanProcessor`, `CollectorExporter`, `ParentBasedSampler`, `SpanExporter`, `ReadOnlySpan`, and the API's span, context and attribute types |
| `tom_core_kernel` | package | `otel_tracer.dart` | `TomTracer`, `TomSpan`, `TomSpanKind`, `TomTracing`, `TomTraceContext`, `TomClosable` and `TomResilientClient` (the export client's default) |
| [configuration](configuration.md) | module | `otel_tracer.dart` | `TomBaseServerConfiguration`, read by `fromConfiguration` |
| [little_things](little_things.md) | module | `otel_tracer.dart` | `TomServerException`, the base of `TomTracingException` |
| [metrics](metrics.md) | module | `otel_tracer.dart` | `TomOtlpHttpTransport` — `urlOf('traces')` and `parseHeaders` |
