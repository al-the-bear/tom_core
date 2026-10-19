# Metrics Module

How a Tom server's metrics leave the process, and the HTTP series it records
itself. The instruments — counters, gauges, histograms and observed gauges —
are `tom_core_kernel`'s `metrics` module (see the kernel's
[metrics guide](../../tom_core_kernel/doc/metrics/metrics.md) and
[API summary](../../tom_core_kernel/doc/api/api_summary_metrics.md)).
Every module of the framework records into one process registry,
`TomMetrics.registry`: the kernel's scheduler its job runs, and the server its
requests, SQL statements, connection pools, cache lookups and rate-limit
refusals. This module reads that registry two ways — a **Prometheus scrape**
and an **OTLP push** — and records the request series.

**The series are recorded whether or not anything reads them.** Both exports
read the same instruments, so a series exists once however it leaves the
process, and which export is on is a deployment's configuration. Both are off
by default.

## Table of Contents

- [Overview](#overview)
- [The Series](#the-series)
  - [Requests](#requests)
  - [Data sources](#data-sources)
  - [Caches and rate limits](#caches-and-rate-limits)
  - [Jobs and the outbox](#jobs-and-the-outbox)
- [Cardinality](#cardinality)
- [The Scrape Endpoint](#the-scrape-endpoint)
  - [Why it is answered before authentication](#why-it-is-answered-before-authentication)
  - [The token](#the-token)
- [Configuration](#configuration)
- [OTLP Export](#otlp-export)
  - [Cumulative, over HTTP, in JSON](#cumulative-over-http-in-json)
  - [Headers](#headers)
  - [Failures and the final push](#failures-and-the-final-push)
  - [One transport for every signal](#one-transport-for-every-signal)
- [Per-Isolate Registries](#per-isolate-registries)
- [Failure Keys](#failure-keys)
- [Not Yet Implemented](#not-yet-implemented)
- [Verification](#verification)
- [Core Components](#core-components)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `tomRequestMetricsMiddleware` | function | The middleware recording `tom_http_server_requests` and `tom_http_server_request_duration_seconds` for every request |
| `tomMetricsEndpointMiddleware` | function | The middleware answering a Prometheus scrape of the registry, ahead of authentication |
| `tomUnmatchedRoute` | const String | `'unmatched'` — the `route` label of a request no endpoint matched |
| `TomOtlpHttpTransport` | class | Posts OTLP/HTTP JSON bodies to `<endpoint>/v1/<signal>`; knows no signal |
| `TomOtlpMetricsExporter` | class | Pushes the registry to an OTLP receiver every interval, and once more on close |
| `tomOtlpMetricsJson` | function | A registry snapshot as an OTLP `ExportMetricsServiceRequest` in the JSON encoding |
| `TomOtlpExportException` | class | An export that did not reach the receiver or was refused, and headers that cannot be read |

The module is two files: `metrics_middleware.dart` holds the request series and
the scrape endpoint, `otlp_exporter.dart` the transport, the exporter and the
JSON encoding. Neither declares an instrument type; those are the kernel's.

`TomServer.start` wires both from configuration: the scrape middleware when
`metricsEndpoint` is on, the request middleware always, and the exporter — kept
as `TomServer.metricsExporter` — when `otlpEndpoint` names a receiver. See
[server.md](server.md#the-pipeline) for where the two middlewares sit.

## The Series

Every series the framework records, by the module that records it. A counter
is exposed with the `_total` suffix (`tom_http_server_requests_total`), a
histogram as `_bucket`, `_sum` and `_count`. Durations are in seconds.

### Requests

| Series | Instrument | Labels | Recorded by |
| ------ | ---------- | ------ | ----------- |
| `tom_http_server_requests` | counter | `method`, `route`, `status` | `tomRequestMetricsMiddleware`, for every request answered |
| `tom_http_server_request_duration_seconds` | histogram | `method`, `route` | `tomRequestMetricsMiddleware` — the time from the outer edge of the pipeline to the response |

The middleware sits outside both error layers, so a request refused during
authentication — a `401`, a tenancy refusal, a rate-limit `429` — is counted with
the status the client received. An error that escapes every layer is counted
as a `500` and rethrown. A scrape is answered before this middleware and is not
counted.

### Data sources

Recorded by `TomSqlDatasource`, the base both the MariaDB and the PostgreSQL
drivers extend, so every SQL data source reports the same series. The
`datasource` label is `TomSqlDatasource.registeredName`: the name the data
source is registered under, which `TomDataSourceInfo.initialize` records with
`registerAs`. A tenant's own pool is registered as `<base>@<tenant>`, so the
usage of each tenant's pool is a series of its own. The series names are
exported as constants beside the class.

| Series | Constant | Instrument | Labels | Measures |
| ------ | -------- | ---------- | ------ | -------- |
| `tom_db_statement_duration_seconds` | `tomDbStatementDurationMetric` | histogram | `datasource`, `operation` | One statement on a connection already held — the wait for the connection is not part of it. `operation` is `query`, `command`, `prepare`, `prepared` or `driver` (`withDriverConnection`). |
| `tom_db_statement_errors` | `tomDbStatementErrorsMetric` | counter | `datasource`, `operation` | Statements that threw. |
| `tom_db_pool_connections` | `tomDbPoolConnectionsMetric` | observed gauge | `datasource`, `state` | The pool when a snapshot is taken: `idle`, `in_use`, `waiting` (statements queued for a connection) and `max` (the configured `poolMaxSize`). Reported while the data source is open; `close` withdraws it. |
| `tom_db_pool_acquire_duration_seconds` | `tomDbPoolAcquireDurationMetric` | histogram | `datasource` | How long a statement waited for a pooled connection, including a transaction's first statement taking the connection it then keeps. |
| `tom_db_pool_acquire_failures` | `tomDbPoolAcquireFailuresMetric` | counter | `datasource` | Acquires that failed — the acquire timeout, or a connection that could not be opened. |

A statement inside a transaction runs on the transaction's pinned connection
and is timed the same way; `in_use` counts that connection for as long as the
transaction holds it. See [datasources.md](datasources.md#the-connection-pool).

### Caches and rate limits

| Series | Constant | Instrument | Labels | Recorded by |
| ------ | -------- | ---------- | ------ | ----------- |
| `tom_cache_lookups` | `tomCacheLookupsMetric` | counter | `cache`, `result` | `TomCache` reads (`fromNameCache`, `fromTypeCache`). `result` is `hit`, `miss` or `expired` — an entry found past its deletion time, which reads as a miss. The hit rate is `hit` over the sum of the three. A read a worker isolate forwards is counted once, by the isolate that holds the cache. |
| `tom_rate_limit_refusals` | `tomRateLimitRefusalsMetric` | counter | `rule`, `tenant` | `tomRateLimitMiddleware`, for every request a rule refused. `tenant` is the request's tenant, or `tomNoTenantLabel` (`none`) outside any. |

See [cache.md](cache.md) and [ratelimit.md](ratelimit.md).

### Jobs and the outbox

The scheduler is the kernel's, and so are its series; they are listed here
because a server is where they are read. `job` is the registered job name.

| Series | Instrument | Labels | Measures |
| ------ | ---------- | ------ | -------- |
| `tom_job_start_lag_seconds` | histogram | `job` | How late a run started after it became due |
| `tom_job_run_duration_seconds` | histogram | `job` | How long an attempt ran |
| `tom_job_runs` | counter | `job`, `outcome` | Attempts ended: `succeeded`, `retried` or `failed` |
| `tom_job_last_success_timestamp_seconds` | gauge | `job` | When a run last succeeded on this node, in seconds since the epoch |
| `tom_job_backlog` | observed gauge | `job` | Runs due and not yet claimed |
| `tom_job_backlog_age_seconds` | observed gauge | `job` | How long the oldest unclaimed due run has been due |

The two backlog gauges are read from the job store when a snapshot is taken —
for a shared queue, from `TomSqlJobStore.backlog`, one grouped `SELECT` over the
`tom_job_run` table — and report only the jobs registered with the scheduler
that observes them, so two schedulers sharing one store do not both report
every job. See [scheduling.md](scheduling.md#operating-notes).

**The messaging outbox is a job.** It runs on the scheduler as
`messaging.outbox` (`tomOutboxJobName`), so its delivery lag is
`tom_job_start_lag_seconds{job="messaging.outbox"}`, its queue
`tom_job_backlog{job="messaging.outbox"}` and its failures
`tom_job_runs{job="messaging.outbox",outcome="failed"}`. There is no separate
outbox series. See [messaging.md](messaging.md).

## Cardinality

Every distinct set of label values is a series the registry holds for the life
of the process, and a series a scrape transfers and a time-series database
stores. So the framework labels only bounded dimensions:

- **`route` is the endpoint's pattern, never the path.** The endpoint pipeline
  writes the pattern of the endpoint that matched — `/tasks/<id>` — into the
  request's `TomRequestLogInfo.route`, and the middleware reads it from there.
  `/tasks/41` and `/tasks/42` are one series.
- **A request no endpoint matched is `unmatched`** (`tomUnmatchedRoute`). That
  includes a scan of random paths, which adds one series rather than one per
  path, and a request refused before routing — by authentication or a rate
  limit — which never reached an endpoint.
- **No label carries a user, a key or a raw value.** `tenant` (rate-limit
  refusals) and the `@<tenant>` suffix of a tenant's pool are bounded by the
  deployment's tenants; `cache`, `rule`, `job` and `datasource` by its
  configuration.

An application recording its own series into `TomMetrics.registry` is held to
the same rule; nothing enforces it.

## The Scrape Endpoint

`tomMetricsEndpointMiddleware` answers `GET` of its path — `/metrics` by
default, `metricsPath` in a server — with the registry's snapshot in the
Prometheus text exposition format (`tomPrometheusText`, content type
`tomPrometheusContentType`). `HEAD` is answered with the headers and no body.
Every other request, including another method on the same path, is passed on.

### Why it is answered before authentication

`TomServer.start` places it at the outer edge of the pipeline, directly inside
the request-log seeding and ahead of the request metrics, the logging, both
error layers, authentication and rate limiting. A scrape is infrastructure,
like a probe: it has no user, no tenant and no business being rate-limited,
logged as an access, or counted as a request. Answered as an ordinary endpoint
it would pass through all of those — and the scraper's bearer token, which is
not a JWT, would be logged as a refused credential on every scrape.

### The token

With a non-empty `metricsToken`, a scrape must present
`Authorization: Bearer <token>` — Prometheus' `authorization` (or
`bearer_token`) setting. Anything else is answered `401` with
`WWW-Authenticate: Bearer` and no body. The comparison takes time that depends
on the length of the expected value only, wherever the presented token differs,
so the token cannot be discovered a byte at a time.

Without a token the endpoint is open, which is right only where the port is
reachable by the scraper alone. `metricsToken` is secret-bearing: supply it from
the environment or a secret reference, never from a checked-in configuration.

```yaml
# prometheus.yml
scrape_configs:
  - job_name: tom_server
    scheme: https
    authorization:
      credentials_file: /etc/prometheus/tom_metrics_token
    static_configs:
      - targets: ['api.example.com:8080']
```

## Configuration

Six keys of `TomBaseServerConfiguration`, each with its environment name (see
[configuration.md](configuration.md#publishing-metrics)):

| Key | Environment | Type | Default | Effect |
| --- | ----------- | ---- | ------- | ------ |
| `metricsEndpoint` | `METRICS_ENDPOINT` | `bool` | `false` | Answer Prometheus scrapes, ahead of authentication |
| `metricsPath` | `METRICS_PATH` | `String` | `/metrics` | The path scrapes are answered at |
| `metricsToken` | `METRICS_TOKEN` | `String` | empty | The bearer token a scrape must present; empty leaves the endpoint open. **Secret-bearing.** |
| `otlpEndpoint` | `OTLP_ENDPOINT` | `String` | empty | The OTLP/HTTP receiver's base URL, such as `http://collector:4318`; empty pushes nothing |
| `otlpHeaders` | `OTLP_HEADERS` | `String` | empty | Headers of every export, as `key=value,key=value`; may carry a credential |
| `otlpMetricsIntervalSeconds` | `OTLP_METRICS_INTERVAL_SECONDS` | `int` | `60` | How often metrics are pushed |

```yaml
# assets/config-resources_default.yaml
metricsEndpoint: true
metricsToken: "${METRICS_TOKEN}"
otlpEndpoint: "http://otel-collector:4318"
otlpHeaders: "x-tenant=ops"
```

The request series are recorded with or without either export.

## OTLP Export

OTLP is the OpenTelemetry protocol a collector receives — the OpenTelemetry
Collector, Grafana Alloy, a vendor's agent. With `otlpEndpoint` set,
`TomServer.start` creates a `TomOtlpMetricsExporter` over a
`TomOtlpHttpTransport`, describes the process with the resource attribute
`service.name` (the configured `appId`, or `tom_server` without one), starts it,
keeps it as `TomServer.metricsExporter` and registers it with the shutdown
cleanup.

### Cumulative, over HTTP, in JSON

Each push posts the whole snapshot to `<otlpEndpoint>/v1/metrics` as an
`ExportMetricsServiceRequest` in the protobuf JSON encoding
(`tomOtlpMetricsJson`), which every OTLP/HTTP receiver accepts:

| Instrument | OTLP data | Temporality |
| ---------- | --------- | ----------- |
| counter | `sum`, monotonic | cumulative |
| gauge, observed gauge | `gauge` | — |
| histogram | `histogram`, explicit buckets | cumulative |

**Cumulative**: every push carries each series' total since the registry's
start time, the temporality Prometheus also uses. A lost push loses nothing —
the next one carries the same totals, grown — and a receiver that wants deltas
computes them. 64-bit integers (counts, timestamps) are strings, as the JSON
mapping writes them. The instrumentation scope is `tom_core`.

### Headers

`otlpHeaders` is read by `TomOtlpHttpTransport.parseHeaders` in the form the
standard `OTEL_EXPORTER_OTLP_HEADERS` variable uses: `key=value` entries
separated by commas, keys lower-cased, values percent-decoded — so
`Authorization=Bearer%20abc` sends `authorization: Bearer abc`. Empty entries are
skipped; an entry with no `=` is refused with `otlp.config.invalid_headers`
when the server starts.

### Failures and the final push

A push that cannot reach the receiver, does not answer within ten seconds, or
is answered anything but a `2xx` is `otlp.export.failed`. The periodic push logs
it as a warning and carries on; the next push carries the same totals, so
nothing is lost but freshness. `export()` called directly throws it.

`close()` stops the timer and pushes **once more** before closing the HTTP
client, so a server shutting down does not lose what it counted since the last
push. The shutdown cleanup closes the exporter; a second `close` does nothing.

### One transport for every signal

`TomOtlpHttpTransport` knows nothing about metrics: it posts a JSON body to
`<endpoint>/v1/<signal>` with the configured headers (`urlOf` names the URL).
The metrics exporter is its first user and posts `v1/metrics`. Tracing is
designed on the same transport: a trace exporter posts its spans to
`v1/traces` through it, so a deployment configures one endpoint and one set of
headers for all its telemetry.

## Per-Isolate Registries

`TomMetrics.registry` is ordinary memory, so each isolate has its own. The
framework records on the isolate that serves requests and runs the scheduler,
and that is the registry a scrape and the exporter read. Work handed to a
worker isolate is measured where its result comes back — a cache read a worker
forwards is counted by the isolate holding the cache. A server that serves from
several isolates (shelf's `shared` binding) runs a pipeline per isolate, so a
scrape is answered by whichever isolate accepted it and reports that isolate's
counts; they are not summed across isolates in process.

## Failure Keys

| Key | Raised by | Meaning |
| --- | --------- | ------- |
| `otlp.export.failed` | `TomOtlpHttpTransport.export`, `TomOtlpMetricsExporter.export` | The receiver could not be reached, did not answer within the timeout, or answered other than `2xx`. Parameters `signal`, `url`, and `status` when it answered. |
| `otlp.config.invalid_headers` | `TomOtlpHttpTransport.parseHeaders` | An `otlpHeaders` entry without `=`. |

`TomOtlpExportException` extends `TomServerException` with
`clientThrow: false`: it is the server's own failure, never a client's answer.

## Not Yet Implemented

- **No series for an installation-wide connection cap or a cache epoch.**
  `tom_core` has neither: each data source's pool is capped by its own
  `poolMaxSize` (reported as `state="max"`), and a cache has no epoch counter.
  Nothing records what does not exist.
  <!-- unpinned: absence — neither an installation-wide pool cap nor a cache epoch exists in tom_core -->
- **No tracing yet.** The OTLP transport is signal-neutral and a trace exporter
  is designed to post `v1/traces` through it, but no spans are recorded today.
  <!-- unpinned: absence — no span is recorded -->
- **OTLP over HTTP with JSON only.** No gRPC and no protobuf bodies: JSON over
  HTTP is the encoding every receiver accepts and needs no generated code.
  <!-- unpinned: decision — JSON over HTTP is the one encoding every receiver accepts -->
- **Registries are not merged across isolates.** Each isolate's registry is its
  own; see [Per-Isolate Registries](#per-isolate-registries).
  <!-- unpinned: decision — a registry is per-isolate memory -->
- **Requests no endpoint matched are not told apart by path.** Every one is
  `route="unmatched"`, so the series says how many there were and with which
  status, not which paths were asked for; the access log is where the paths are.
  <!-- pinned: test/metrics_test.dart › a path no endpoint matched adds one series, whatever the path -->
- **The cardinality rule is not enforced for an application's own series.**
  The framework labels only bounded dimensions; a label an application records
  is its own responsibility.
  <!-- unpinned: absence — no label-cardinality limit exists -->

## Verification

`test/metrics_test.dart` covers the module without a database: a request
counted under its route pattern and not its path, a path no endpoint matched
adding one `unmatched` series however many paths are scanned, an escaping error
counted as a `500`; the scrape endpoint not counting itself, refusing a scrape
without the configured token (none, a wrong one, a longer one), answering
`HEAD` without a body and passing other methods on, and — in
`exposes the request, cache, rate-limit and job series` — one scrape carrying a
request, a rate-limit refusal under its tenant, a cache hit and miss and the
kernel's job series; an expired cache entry counted as `expired`; and the OTLP
exporter posting a counter, a gauge and a histogram to `v1/metrics` with the
configured headers and cumulative temporality, a refusing receiver reported
with its status, `close` pushing once more and only once, and headers read in
the `OTEL_EXPORTER_OTLP_HEADERS` form.

`test/metrics_db_test.dart`, tagged `db`, runs the data-source series against
the database the DB suites run against — MariaDB or PostgreSQL: the data source
labelled with its registered name, statements timed by operation with a failure
counted, the pool's connections by state, a statement in a transaction timed on
its pinned connection, and a closed data source no longer reported.
`tool/run_db_tests.sh` (MariaDB) or `tool/run_db_tests_postgres.sh`
(PostgreSQL) starts a database for it.

`test/metrics_otel_test.dart`, tagged `otel`, has the exports read by their
consumers: promtool (`promtool check metrics`) accepts the scrape of every
series the framework records, and an OpenTelemetry Collector receives an export
with every series and its points. It skips unless both are available;
`tool/run_otel_tests.sh` starts the collector with `tool/otel/collector.yaml`,
pulls promtool's image (`prom/prometheus`), runs the suite and treats a run in
which every test skipped as a failure.

The series the kernel records are the kernel's to test; `TomSqlJobStore.backlog`
is covered by the kernel's scheduling contract suite, which
`test/scheduling_db_test.dart` runs against the SQL store.

```bash
dart run example/metrics/metrics_example.dart
tool/run_otel_tests.sh
```

`example/metrics/metrics_example.dart` walks the module without a server or a
database: requests through the server's outer middlewares counted by route
pattern, an unmatched path, a scrape refused without the token and answered
with it, a cache hit and miss in the same scrape, and an OTLP push to an
in-process receiver, read back. Every step checks its own result, and
`test/examples_test.dart` runs it.

## Core Components

- **`tomRequestMetricsMiddleware`** — the request series; reads the route from
  `TomRequestLogInfo.route`, `tomUnmatchedRoute` when none.
- **`tomMetricsEndpointMiddleware`** — the scrape: path, token, and the registry
  it reads (`TomMetrics.registry` unless given).
- **`TomOtlpHttpTransport`** — `endpoint`, `headers`, `timeout`; `parseHeaders`,
  `urlOf`, `export` and `close`.
- **`TomOtlpMetricsExporter`** — `transport`, `registry`, `resource`,
  `interval`; `export`, `start` and `close`.
- **`tomOtlpMetricsJson`** — the encoding both the exporter and a test read.
- **`TomOtlpExportException`** — every failure this module raises.

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | `otlp_exporter.dart` | `Timer` and `unawaited`, the periodic push |
| `dart:convert` | dart | `otlp_exporter.dart` | `jsonEncode`, the body of an export |
| `http` | package | `otlp_exporter.dart` | `Client`, which posts an export |
| `shelf` | package | `metrics_middleware.dart` | `Request`, `Response` and `Middleware` |
| `tom_core_kernel` | package | every file | `TomMetrics`, `TomMetricRegistry`, `TomCounter`, `TomHistogram`, `TomMetricFamily`, `TomMetricKind`, `TomMetricPoint`, `tomPrometheusText`, `tomPrometheusContentType`, `TomClosable` and `tomLog` |
| [little_things](little_things.md) | module | `otlp_exporter.dart` | `TomServerException`, the base of `TomOtlpExportException` |
| [server](server.md) | module | `metrics_middleware.dart` | `TomRequestLogInfo`, whose `route` the endpoint pipeline sets |
