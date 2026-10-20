# Health Check Module

Ready-made `GET /health` and `GET /ready` endpoints for an orchestrator's
liveness and readiness probes. Both are public (no authentication) and unlogged,
and both return a plain-text status string produced by a pluggable
`TomHealthAnalyzer` — `"OK"` by default, or any descriptive string a custom
analyzer returns — with the verdict in the status code.

Two routes, because liveness ("am I running") and readiness ("can I serve
traffic") have opposite consequences — see
[Two Questions, Two Routes](#two-questions-two-routes). Each has its own
process-wide analyzer, installed through a function that records the
replacement — see [Installing an Analyzer](#installing-an-analyzer) — and both
answer through a guard, so an analyzer that hangs or throws cannot stop a probe
from answering — see
[When the Analyzer Does Not Answer](#when-the-analyzer-does-not-answer).

`GET /ready` answers out of the box with the framework's own question — are the
data sources answering, is no migration running or failed, are the started
outboxes delivering — through `TomFrameworkReadinessAnalyzer`, which
`TomServer.start` installs unless the application installed a readiness
analyzer of its own; see
[The Framework Readiness Checks](#the-framework-readiness-checks). Once a graceful
shutdown has begun it answers `503 shutting down` instead, while `GET /health`
still asks its liveness analyzer; see
[While the server shuts down](#while-the-server-shuts-down).

## Table of Contents

- [Overview](#overview)
- [The Probe Endpoints](#the-probe-endpoints)
- [Two Questions, Two Routes](#two-questions-two-routes)
  - [Kubernetes](#kubernetes)
  - [While the server shuts down](#while-the-server-shuts-down)
- [The Framework Readiness Checks](#the-framework-readiness-checks)
  - [What is checked](#what-is-checked)
  - [The body](#the-body)
  - [Composing it into an application analyzer](#composing-it-into-an-application-analyzer)
  - [Why the outbox backlog is not checked by default](#why-the-outbox-backlog-is-not-checked-by-default)
- [Customizing the Health Check](#customizing-the-health-check)
  - [Installing an Analyzer](#installing-an-analyzer)
  - [When the Analyzer Does Not Answer](#when-the-analyzer-does-not-answer)
- [How It Is Wired](#how-it-is-wired)
- [Not Yet Implemented](#not-yet-implemented)
- [Verification](#verification)
- [Core Components](#core-components)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomHealthService` | abstract class | Declares the `GET /health` (liveness) and `GET /ready` (readiness) endpoints |
| `TomHealthServer` | class | The default implementation; delegates each route to its own analyzer |
| `TomHealthAnalyzer` | abstract class | The pluggable health-check contract (`analyzeHealth`) |
| `TomHealthStatus` | class | What an analyzer concluded: a verdict a probe acts on, and a message a human reads |
| `TomHealthVerdict` | enum | `healthy` (200) or `unhealthy` (503) — the two answers HTTP offers a probe |
| `TomDefaultHealthAnalyzer` | class | The default analyzer; always reports healthy |
| `TomReadinessCheck` | class | One check of the framework readiness analyzer: what was checked, whether it passed, what was seen |
| `TomFrameworkReadinessAnalyzer` | class | The framework's readiness answer: data sources, migrations, started outboxes |

## The Probe Endpoints

`TomHealthService.health` and `TomHealthService.ready` are annotated as `GET`
endpoints at `/health` and `/ready`, both of which `produce` plain text, are
marked `@TomPublicAccess` (so orchestration probes reach them without a token),
and set `logRequests: false` so frequent probe traffic does not flood the logs.
Like every endpoint they are mounted by the endpoints pipeline (see
`doc/endpoints.md`) when the server starts.

**The status code is the verdict, and the body is the reason:**

| Verdict | Status | Body |
| ------- | ------ | ---- |
| `TomHealthVerdict.healthy` | `200` | the analyzer's message, `OK` by default |
| `TomHealthVerdict.unhealthy` | `503` | the analyzer's message, which says what failed |

Which is what makes an ordinary probe correct. A load balancer's default check
reads the status code and nothing else, as does a Kubernetes `httpGet` probe
unless the deployment adds a body matcher; both stop sending traffic to a
process whose analyzer says it cannot serve. A probe that wants the *reason*
reads the body, where it has always been.

All three of those choices are asserted against the mounted route, in
`test/endpoints_pipeline_test.dart`, in the group named
`healthcheck GET /health route`;
deleting any one of the three fails that group. It is also where the route's
answer to a swapped-in analyzer is pinned. `test/healthcheck_test.dart` covers
the analyzer contract itself, away from the route.

`@TomPublicAccess` is checked against a server with
`TomResourceKeyProtection.globalSettingProtectionDefault` turned **on**, because
that is the only setting under which it can be observed: with protection off, an
endpoint declaring no access control serves anonymously anyway, so an ordinary
unauthenticated request cannot tell the annotation from its absence.

## Two Questions, Two Routes

`GET /health` is **liveness** — am I running. `GET /ready` is **readiness** —
can I serve traffic. Each has its own static analyzer, and each defaults to the
always-healthy one, so a server that configures neither answers `200` on both.

They are two routes because the two questions have **opposite consequences**: a
failing liveness probe restarts the process, a failing readiness probe takes it
out of the load balancer and leaves it running. One verdict cannot serve both.
"The container started but its database is unreachable" is ready-false with
live-true — and with one route a deployment has to pick which consequence it
wants:

- report unhealthy, and the liveness probe restarts a pod that would have
  recovered on its own, in a loop, because restarting does not make the database
  come back;
- stay healthy so liveness is safe, and the readiness probe reports ready while
  traffic arrives at a process that cannot serve it.

**So the split is by what the check touches.** A liveness analyzer looks at the
*process* — is the event loop turning, is a critical isolate still there. A
readiness analyzer looks at what the process *needs* — the connection pool, the
cache, the downstream API. A dependency being down is a reason to stop receiving
traffic and not a reason to be killed, which is the single sentence that decides
where a given check belongs.

```dart
// Dependencies: a failure here empties the load balancer, and the pod lives.
TomHealthServer.installReadinessAnalyzer(DependencyAnalyzer());

// The process itself: a failure here is a restart, so put very little in it.
TomHealthServer.installLivenessAnalyzer(TomDefaultHealthAnalyzer());
```

Most deployments need only the first. The liveness default answers `200` for as
long as the isolate can serve a request at all, which is very nearly the
question a liveness probe is asking.

A route per question rather than one route with a `?probe=ready` parameter:
query parameters on a health check are awkward to configure in several
orchestrators, and a single route stays a single point of failure for both
answers. `/ready` rather than `/health/ready`, because a sub-path reads as a
refinement of the liveness answer and these are two questions rather than one
asked in more detail — and it is the path the platforms' own examples use.

### Kubernetes

```yaml
livenessProbe:
  httpGet: { path: /health, port: 8080 }
  periodSeconds: 10
  timeoutSeconds: 10
  failureThreshold: 3          # restart only a process that stopped answering
readinessProbe:
  httpGet: { path: /ready, port: 8080 }
  periodSeconds: 5
  timeoutSeconds: 10
  failureThreshold: 2          # leave the load balancer quickly, come back by itself
```

No body matcher on either: the verdict is the status code.

`timeoutSeconds` is raised above the framework's own five-second deadline on
purpose. Kubernetes defaults it to **1**, which is shorter than any real
dependency check and shorter than the deadline — so the probe would give up
first and the framework's `TIMEOUT:` answer, the whole point of the deadline,
would never be read. Whichever of the two deadlines is shorter is the one that
decides what the orchestrator sees; make it the framework's, which answers,
rather than the probe's, which does not.

**The two probes see different checks.** `/health` is answered by the
always-healthy default unless the application installs more, and the framework
readiness checks never reach it — so a database outage takes the pod out of the
Service's endpoints and does not restart it. `/ready` is answered by
`TomFrameworkReadinessAnalyzer` (see below), whose data-source check is one
`SELECT 1` per data source under a two-second deadline by default, well inside
both the framework's deadline and the probe's. While a migration runs in the
process `/ready` answers not ready, and after one failed it stays not ready
with the error in the body — rather than a liveness failure restart-looping a
pod on a schema that a restart will not change.

### While the server shuts down

A server's graceful shutdown (see
[server.md](server.md#graceful-shutdown)) begins by calling
`TomHealthServer.markShuttingDown()`. From then on every `GET /ready` answers
`503` with the body `shutting down`, **without asking the readiness analyzer** —
whatever the data sources say, a server that is stopping is not one to send
traffic to, and an analyzer that takes its deadline to answer would only delay
the load balancer noticing. The call is logged once at info:

```text
INFO  TomHealthServer: readiness now answers 503 shutting down
```

**Liveness is left alone.** `GET /health` keeps asking its analyzer, so a
draining process answers `200`: it is alive, and a restart would cut off the
requests it is finishing.

| | Before the shutdown | Once it has begun |
| - | ------------------- | ----------------- |
| `GET /ready` | the readiness analyzer's verdict | `503 shutting down` |
| `GET /health` | the liveness analyzer's verdict | unchanged |

`TomHealthServer.isShuttingDown` says whether the mark is set. It is
process-wide like the analyzers and is not cleared by the shutdown itself — the
process is ending — but `resetHealthChecks()` clears it, for a test or an
example that drove a shutdown in-process.

Both probe paths are passed by the shutdown's request gate, so a probe arriving
on a connection kept alive from before still gets this answer after the server
has stopped accepting connections. A probe on a new connection is refused once
the listener has closed — see
[server.md](server.md#kubernetes) for what that means for a liveness probe's
`failureThreshold`.

## The Framework Readiness Checks

Every Tom server needs the same things before it can serve traffic: its data
sources answering, its schema migrated, its message outboxes delivering.
`TomFrameworkReadinessAnalyzer` asks exactly that, and `TomServer.start`
installs it on `GET /ready` when two things hold:

- the `frameworkReadiness` configuration key is on — the default (environment
  `FRAMEWORK_READINESS`); and
- the readiness analyzer is still the default `TomDefaultHealthAnalyzer`, so an
  analyzer the application installed before `start()` is never replaced.

Liveness (`GET /health`) is untouched: none of these checks is a reason to
restart the process.

### What is checked

| Check | Subject in the body | Ready when |
| ----- | ------------------- | ---------- |
| every registered data source | `datasource <name>` | it reports operational, and an SQL data source answers `SELECT 1` within `dataSourceTimeout` (two seconds by default). A `delegateTo` alias is checked once, under its target. |
| migrations | `migrations` | `TomDbMigrations.lastRun` is not `running` and not `failed`. A process that never called `migrateDatabases` passes — `not run in this process` — because a deployment whose schema is applied by a DBA or a job never calls it, and a check waiting for it would never pass. |
| every started outbox | `outbox <jobName>` | its scheduler is running — an outbox in `TomMessageOutbox.started` whose scheduler was stopped is `not delivering` — and, only when `maxOutboxWait` is set, no due message has waited longer than it. |

The registries it reads are static state, and static state belongs to an
isolate: with `isolateCount` above one, the isolate that accepts a probe's
connection answers for the data sources it registered and the outboxes it
started.

`checks()` returns the checks as `TomReadinessCheck`s — `subject`, `passed`,
`detail` — in the order the body lists them, for an application that wants to
read them rather than the text.

### The body

The first line is `ready` or `not ready`, and one line per check follows, so the
reason is on the wire next to the status code:

```text
not ready
datasource app: ok
datasource reporting: SELECT 1 did not answer within 0:00:02.000000
migrations: ok
outbox messaging.outbox: ok
```

A readiness probe reads the status (`200` or `503`) and nothing else; an
operator who runs `curl /ready` reads which dependency it was.

### Composing it into an application analyzer

An application with dependencies of its own — a search index, a downstream API —
installs its own readiness analyzer, which keeps `start()` from installing the
framework's, and asks the framework's first:

```dart
class AppReadiness extends TomHealthAnalyzer {
  final _framework = TomFrameworkReadinessAnalyzer();

  @override
  Future<TomHealthStatus> analyzeHealth() async {
    final framework = await _framework.analyzeHealth();
    if (!framework.isHealthy) return framework;
    return await searchIndexAnswers()
        ? framework
        : TomHealthStatus.unhealthy('${framework.message}\nsearch index: unreachable');
  }
}

// Your own probe — not framework API.
Future<bool> searchIndexAnswers() async => true;

TomHealthServer.installReadinessAnalyzer(AppReadiness());
```

The order matters only for the message: the framework's lines come first, so the
body still reads top-down from the most fundamental dependency.

### Why the outbox backlog is not checked by default

`maxOutboxWait` is off unless set, and deliberately. Every node of a cluster
delivers from the same queue, so a backlog caused by a slow mail relay or a
throttling SMS gateway would take **every** node out of the load balancer at
once — refusing the requests that are not waiting on a message at all, for a
problem none of the nodes can fix. A stopped scheduler is checked always,
because that is a fault of the one process. Set `maxOutboxWait` where sending
messages is the service's purpose and a node that cannot is of no use:

```dart
TomHealthServer.installReadinessAnalyzer(
  TomFrameworkReadinessAnalyzer(maxOutboxWait: const Duration(minutes: 10)),
);
```

## Customizing the Health Check

Each route's body is delegated to its own global `TomHealthAnalyzer`. Replace
either before the server starts to add real checks:

```dart
class MyHealthAnalyzer extends TomHealthAnalyzer {
  @override
  Future<TomHealthStatus> analyzeHealth() async {
    final dbOk = await checkDatabaseConnection();
    final cacheOk = await checkCacheService();
    if (dbOk && cacheOk) return const TomHealthStatus.healthy();
    return TomHealthStatus.unhealthy('db=$dbOk, cache=$cacheOk');
  }
}

// Your own probes — not framework API.
Future<bool> checkDatabaseConnection() async => true;
Future<bool> checkCacheService() async => true;

// Install globally before the server starts. A dependency check belongs on
// readiness: a database being down is a reason to stop receiving traffic and
// not a reason for the process to be restarted.
TomHealthServer.installReadinessAnalyzer(MyHealthAnalyzer());
```

An analyzer returns a **verdict** and a **message**, and they are two facts
rather than one. The verdict is what a probe acts on and decides the status
code; the message is free-form, is served as the body verbatim, and is what a
person reads. Encoding both into one string — `"OK"` meaning healthy and
anything else meaning not — is what forced every consumer to parse, made a typo
in an analyzer a wrong verdict, and left an orchestrator no way to act without a
body matcher.

**There are two verdicts, and deliberately not three.** HTTP offers a probe
exactly two answers: send me traffic, or do not. A third verdict would either
map to one of those two — a distinction no probe can act on — or invent a status
code no orchestrator reads. Gradation belongs in the message, which is where
`db=false, cache=true` says what a number cannot.

### Installing an Analyzer

`livenessAnalyzer` and `readinessAnalyzer` are read-only. Installation goes
through a function:

| Call | Effect |
| ---- | ------ |
| `TomHealthServer.installLivenessAnalyzer(a)` | `a` answers every `GET /health` |
| `TomHealthServer.installReadinessAnalyzer(a)` | `a` answers every `GET /ready` |
| `TomHealthServer.installHealthTimeout(d)` | `d` is the deadline both probes answer under |
| `TomHealthServer.resetHealthChecks()` | both probes go back to a fresh `TomDefaultHealthAnalyzer`, one instance each, the deadline to its default, and the shutting-down mark is cleared |

**Each call logs at info, naming the outgoing and the incoming analyzer.** That
line is the whole reason installation is a function rather than an assignment.
The analyzers are process-wide globals, so anything in the process can replace
one at any moment — including after the server is serving — and a bare
assignment leaves no trace, which means a deployment answering probes with the
wrong analyzer has nothing to read. The log line is that trace:

```text
INFO  TomHealthServer: readiness analyzer is now DependencyAnalyzer, installed over TomDefaultHealthAnalyzer
```

**Installation is not sealed after startup, and deliberately.** An analyzer has
to be replaceable before the bean context exists, which is what rules out making
it a bean, and the framework has no way to know when a given deployment has
finished installing — so a seal would either be dead code or fire on a legitimate
late install. A late installation is *visible* instead, which is the boundary
that can actually be enforced.

`resetHealthChecks()` is the supported way back for a test or an example that
configured the module. It logs like any other installation, because it is one.

### When the Analyzer Does Not Answer

Every probe runs its analyzer through `TomHealthServer.verdictOf`, which awaits
it under `TomHealthServer.healthTimeout` — five seconds by default — and **turns
every way an analyzer can fail to produce a verdict into a verdict**:

| What the analyzer does | What the probe answers |
| ---------------------- | ---------------------- |
| returns a status | that status, as always |
| does not answer within the deadline | `503` with `TIMEOUT: the <probe> check did not answer within 0:00:05.000000` |
| throws, or returns a future that fails | `503` with `FAILED: the <probe> check threw <error>` |

**The throw is the likelier failure, and the one that changes the response
shape.** The analyzer this module is written for issues a `SELECT 1` through the
datasource; a datasource that is *down* throws rather than hangs, so an
exception is the realistic first encounter with a broken dependency. An
exception leaving the handler is caught by the endpoints pipeline, which answers
its own error envelope — a `500` carrying JSON. That is a different status, a
different content type and a different body from the plain text every probe was
configured to read, and on liveness a `500` is a restart: a database that was
merely unreachable would take the pod down and hand the operator a response its
probe cannot parse.

A synchronous throw — an `analyzeHealth` that is not `async` and raises before
returning a future — is caught too, because the call itself sits inside the
guarded block rather than only the future it returns.

**A timed-out analysis is not started again while it is still running.** A
deadline stops the waiting, not the work — Dart cannot abort a future in flight
— so the analysis a probe gave up on keeps running. The next probe does not
start a second one beside it: it waits on the one still pending, under its own
deadline, and only a probe after that analysis has answered asks afresh. An
analyzer that hangs on every probe therefore leaves one pending future behind,
not one per probe. The deadline that stops the *work* is still the analyzer's
own, which is why an analyzer touching anything remote should carry one.

```dart
TomHealthServer.installHealthTimeout(const Duration(seconds: 2));
```

A zero or negative duration is refused with an `ArgumentError`: it would make
every probe answer `TIMEOUT` before its analyzer ran, which is wrong in the
direction that looks safe — `503` on liveness is a restart.

**Why the framework carries a deadline as well.** `analyzeHealth` is `async`
precisely so a `SELECT 1` and a cache `PING` can be awaited, and a TCP
connection to a host that has dropped off the network does not fail fast: it
waits for the OS connect timeout, over two minutes on Linux. Awaited without a
deadline, `/health` returns *nothing* for that window, so an orchestrator sees a
probe timeout rather than a degraded body — and restarts a process whose only
problem was a slow dependency. A health endpoint is the one endpoint that must
always answer, and "I could not determine my health within five seconds" is a
better answer than no answer.

**An analyzer should still carry its own, shorter deadline.** The framework's
can only say *that* the check did not answer; the analyzer's own can say
**which** dependency was slow. It is also the only one that stops the *work*:
`Future.timeout` stops the waiting, and Dart cannot abort a future in flight, so
an analyzer that hangs on every probe accumulates pending futures at probe
frequency.

`TomHealthServer.verdictOf(analyzer, probeName)` is that logic as a public
seam, so a deployment adding a probe route of its own gets the deadline and the
failure handling rather than a second, thinner spelling of them.

## How It Is Wired

`TomHealthServer` is annotated `@tomComponent` and implements the
`@tomService`-annotated `TomHealthService`, so the endpoints pipeline discovers
it by reflection, resolves its bean, and mounts the `/health` and `/ready`
routes — no manual registration needed. The analyzers are `static` state on
`TomHealthServer`, so a single installation applies to every request.

`TomFrameworkReadinessAnalyzer` is not a component: it is an ordinary analyzer
that `TomServer.start` installs through `installReadinessAnalyzer` — logged like
every installation — when `frameworkReadiness` is on and the readiness analyzer
is still a `TomDefaultHealthAnalyzer`. It reads process-wide state the other
modules keep: `TomDataSourceInfo.datasources`, `TomDbMigrations.lastRun` and
`TomMessageOutbox.started`.

## Not Yet Implemented

- **The analyzers are process-wide.** `TomHealthServer.livenessAnalyzer` and
  `readinessAnalyzer` are `static`, so one installation answers every request on
  every isolate; there is no per-instance, per-port or per-request override. A
  deployment that wants two different *liveness* checks needs two processes.
  <!-- unpinned: absence — no per-instance or per-request override exists -->
- **A timed-out analyzer is not cancelled.** `Future.timeout` stops the waiting,
  not the work, and Dart has no way to abort a future in flight — so an analyzer
  that hangs on every probe accumulates pending futures at probe frequency. The
  remedy is the analyzer's own deadline, on the operation it started.
  <!-- unpinned: untestable — the limit is the language's: Dart cannot abort a future in flight -->

## Verification

`test/healthcheck_test.dart` covers the surface a deployment drives directly:
`TomDefaultHealthAnalyzer`'s verdict, each route delegating to its own analyzer,
that the two are independent in both directions, that installation is read-only
from outside and announces every replacement including a reset, that a hanging
analyzer still produces a verdict within the deadline and a throwing one — sync
or async, early or late — produces one too, and the declared routes. The
*response shape* a throw produces is a pipeline claim, so it is asserted where
the pipeline runs. The
*mounted* routes are a different claim — they are produced by the
reflection-based endpoints pipeline — so they are asserted where that pipeline
runs, in `test/endpoints_pipeline_test.dart`, in the group named
`healthcheck GET /health route`.

Both halves are needed, and which one catches what is worth knowing. The
declared-route tests read the *source*, so they fail the moment a path or a flag
is edited. The mounted-route tests read the *generated mirror*, so they fail
only once reflection has been regenerated — but they are the only ones that
would notice a second `@TomEndpoint` on one service failing to produce a second
route, which is exactly the shape `/ready` has.

`test/structured_logs_readiness_test.dart`, in the group
`framework readiness`, covers the analyzer: ready with nothing registered, not
ready after a failed migration, a started outbox checked and a stopped one not
ready, and a message waiting past `maxOutboxWait` making the server not ready.
Its group `a started server` binds a socket and reads `/ready` answering `200`
and then `503` after a failed migration while `/health` stays `200`, and an
application's own readiness analyzer surviving `start()`.
`test/structured_logs_readiness_db_test.dart` (tagged `db`) covers the data
source check against a real database, in the group `data source readiness`: a
data source that answers is ready, a closed one is not.

`test/graceful_shutdown_test.dart`, in the group `TomGracefulShutdown in
process`, covers readiness during a shutdown: once the shutdown has begun,
`TomHealthServer.isShuttingDown` is set, `/ready` answers `503` and `/health`
`200`, and the probe paths pass the shutdown's request gate while other paths
are refused.

```bash
dart run example/healthcheck/healthcheck_example.dart
dart run example/healthcheck/readiness_logging_example.dart
```

`example/healthcheck/healthcheck_example.dart` shows the analyzer seam and both
failure paths without the router, deliberately: mounting the route means initializing generated
reflection and building a pipeline, which would bury the one thing the example
is about. `example/healthcheck/readiness_logging_example.dart` shows the
framework readiness checks — ready, a failed migration, a stopped outbox — and
the JSON log line a request writes through `tomRequestContextMiddleware`. Every
step of both checks its own result, and `test/examples_test.dart` runs them.

## Core Components

- **`TomHealthService`** — the reflected service interface carrying the
  `GET /health` and `GET /ready` endpoint annotations.
- **`TomHealthServer`** — the reflected default implementation; holds the two
  global analyzers (`livenessAnalyzer`, `readinessAnalyzer`) and the deadline
  (`healthTimeout`) behind `installLivenessAnalyzer` /
  `installReadinessAnalyzer` / `installHealthTimeout` / `resetHealthChecks`,
  runs each route's analyzer through `verdictOf`, and turns the verdict into the
  response with `responseFor`; `markShuttingDown` / `isShuttingDown` turn
  readiness to `503 shutting down` for a graceful shutdown.
- **`TomHealthAnalyzer`** / **`TomDefaultHealthAnalyzer`** — the analyzer
  contract and its always-healthy default.
- **`TomHealthStatus`** / **`TomHealthVerdict`** — what an analyzer concludes:
  the verdict that decides the status code, and the message served as the body.
- **`TomFrameworkReadinessAnalyzer`** / **`TomReadinessCheck`** — the
  framework's readiness answer (data sources, migrations, started outboxes),
  installed on `GET /ready` by `TomServer.start`, and one of its checks.

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | every file | `TimeoutException`, the one `Future.timeout` throws, caught to turn a hung analyzer — or a data source that does not answer `SELECT 1` — into a verdict |
| `shelf` | package | `health_check.dart` | `Response`, because the status code is part of the answer and a `String` has nowhere to put it |
| `tom_core_kernel` | package | `health_check.dart` | `tomReflector` (reflection), `tomComponent` (the bean locator's component annotation), `TomPublicAccess` (an access control), `TomHeader` (the `Content-Type` name), and `TomHttpMethod` / `TomMimeType` (the HTTP vocabulary the endpoint annotation is written in) |
| [datasources](datasources.md) | module | `framework_readiness.dart` | `TomDataSourceInfo` (the registered data sources and whether each is operational) and `TomSqlDatasource` (the `SELECT 1`) |
| [db_migration](db_migration.md) | module | `framework_readiness.dart` | `TomDbMigrations.lastRun`, `TomMigrationRunState` |
| [endpoints](endpoints.md) | module | `health_check.dart` | `tomService` and `TomEndpoint`, the two annotations by which the endpoints pipeline discovers the route |
| [messaging](messaging.md) | module | `framework_readiness.dart` | `TomMessageOutbox.started` and `oldestWaitingSince` |

`health_check.dart` imports exactly three things, and between them they supply
every symbol it uses:

Note that `@tomComponent` and `@TomPublicAccess` are *kernel* annotations even
though the endpoints pipeline is what acts on them: the pipeline resolves the
component's bean and enforces the access control, but neither symbol belongs to
the endpoints module.
