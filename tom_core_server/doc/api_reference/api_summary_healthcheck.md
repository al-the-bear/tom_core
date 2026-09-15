# Tom Core Server API Reference: Health Check Module

Health-check service for server monitoring: `GET /health` (liveness) and
`GET /ready` (readiness), each with a pluggable analyzer, so applications can
report custom status to container orchestration tools (Docker, Kubernetes).

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomHealthStatus](#tomhealthstatus)
  - [TomHealthAnalyzer](#tomhealthanalyzer)
  - [TomDefaultHealthAnalyzer](#tomdefaulthealthanalyzer)
  - [TomHealthService](#tomhealthservice)
  - [TomHealthServer](#tomhealthserver)
- [Enums](#enums)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tomserver/healthcheck/health_check.dart`.

`TomHealthService` is a `@tomService` interface declaring two endpoints, both
public and unlogged: `GET /health` (**liveness** — am I running) and
`GET /ready` (**readiness** — can I serve traffic). `TomHealthServer` is its
`@tomComponent` implementation; it delegates each route to its own static
analyzer — `livenessAnalyzer` and `readinessAnalyzer` — and turns the
`TomHealthStatus` it gets back into the response. Applications provide custom
logic by extending `TomHealthAnalyzer` (overriding `analyzeHealth`) and
installing an instance on either before startup, through
`installLivenessAnalyzer` / `installReadinessAnalyzer`, which log the
replacement; both default to the shipped
`TomDefaultHealthAnalyzer`, which always reports healthy.

Two routes because the questions have **opposite consequences**: a failing
liveness probe restarts the process, a failing readiness probe takes it out of
the load balancer and leaves it running. So the split is by what the check
touches — a liveness analyzer looks at the process, a readiness analyzer at what
the process needs. A dependency being down is a reason to stop receiving traffic
and not a reason to be killed.

**The status code is the verdict and the body is the reason**: `200` for
`TomHealthVerdict.healthy`, `503` for `TomHealthVerdict.unhealthy`, with the
analyzer's message served verbatim either way. That is what makes an ordinary
probe correct — a load balancer's default check and a Kubernetes `httpGet` probe
read the code and nothing else — while a probe that wants the reason still reads
the body.

## Class Hierarchy

```
TomHealthStatus          (a verdict and a message)
TomHealthVerdict  (enum) (healthy 200 / unhealthy 503)

TomHealthAnalyzer  (abstract)
    └── TomDefaultHealthAnalyzer

TomHealthService  (abstract, @tomService)
    └── TomHealthServer  (@tomComponent, implements)
```

## Classes

### TomHealthStatus

What an analyzer concluded: a verdict a probe can act on, and a message a human
can read. The two are separate because they are different facts — encoding both
into one string is what forces every consumer to parse, makes a typo in an
analyzer a wrong verdict, and leaves an orchestrator no way to act without a
body matcher.

- **Extends:** none

#### Constructors

```dart
const TomHealthStatus.healthy([String message = 'OK'])
const TomHealthStatus.unhealthy(String message)
```

The message is optional on `healthy` and required on `unhealthy`: `OK` is what a
human reading a probe log expects and what keeps a `curl` from looking broken,
while an unhealthy answer that does not say why is the one somebody is reading at
three in the morning.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `verdict` | `TomHealthVerdict` | The verdict, which decides the HTTP status (final). |
| `message` | `String` | A free-form description, served as the response body verbatim (final). |
| `isHealthy` | `bool` | *(getter)* Whether `verdict` is `TomHealthVerdict.healthy`. |
| `statusCode` | `int` | *(getter)* The HTTP status this is answered with — `verdict.statusCode`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* Renders `TomHealthStatus(<verdict>: <message>)`. |

### TomHealthAnalyzer

Analyzer for customizing health check responses. Extend and override
`analyzeHealth` to implement checks such as database connectivity, external
service availability, or resource usage.

- **Extends:** none (abstract base)

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `analyzeHealth` | `Future<TomHealthStatus> analyzeHealth()` | Analyzes server health, returning the verdict a probe acts on and the message a person reads. An analyzer that touches anything remote should impose its own timeout and answer unhealthy rather than hang: `/health` is the request an orchestrator uses to decide whether the process is alive, so a slow dependency that hangs it reads as a dead process. |

### TomDefaultHealthAnalyzer

Default health analyzer that always reports healthy.

- **Extends:** `TomHealthAnalyzer`

#### Constructors

```dart
TomDefaultHealthAnalyzer()
```

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `analyzeHealth` | `Future<TomHealthStatus> analyzeHealth()` | *(override)* Always returns `TomHealthStatus.healthy()`. |

### TomHealthService

Health check service interface for server health monitoring. Declares the
`GET /health` endpoint that container orchestration tools call to verify
availability. Each response body is the installed `TomHealthAnalyzer`'s message
verbatim — so `"OK"` is the `TomDefaultHealthAnalyzer`'s answer rather than a
constant of the endpoint — and the status code is the verdict. Annotated
`@tomReflector` / `@tomService`.

- **Extends:** none (abstract)

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `health` | `Future<Response> health()` | The `GET /health` endpoint — **liveness**: a plain-text status string with the status code carrying the verdict. Marked `@TomPublicAccess` and `logRequests: false`. Returns a shelf `Response` rather than a `String` because the status is part of the answer and a `String` has nowhere to put it — the pipeline's documented escape hatch, used here rather than inventing a directive in `endpoint_results.dart` because one caller is not a pattern. |
| `ready` | `Future<Response> ready()` | The `GET /ready` endpoint — **readiness**: the same shape, answered by `TomHealthServer.readinessAnalyzer`. `/ready` rather than `/health/ready`, because a sub-path reads as a refinement of the liveness answer while these are two questions; it is also the path the platforms' own examples use. |

### TomHealthServer

Default implementation of `TomHealthService`. Delegates each route to its own
analyzer; set either to a custom `TomHealthAnalyzer` before server startup for
advanced logic. Annotated `@tomReflector` / `@tomComponent`.

- **Implements:** `TomHealthService`

#### Constructors

```dart
TomHealthServer()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `livenessAnalyzer` | `static TomHealthAnalyzer get` | The analyzer every `GET /health` request is answered by (defaults to `TomDefaultHealthAnalyzer`). Read-only: install with `installLivenessAnalyzer`. Named for the question rather than for the module, now that there are two: a `healthAnalyzer` beside a `readinessAnalyzer` would read as though it covered both. |
| `readinessAnalyzer` | `static TomHealthAnalyzer get` | The analyzer every `GET /ready` request is answered by — a separate instance, so installing one does not silently change the other. Defaults to always-ready: "not ready until told" would leave a deployment that never configures readiness with an empty load balancer, a healthy process and a passing liveness probe — a failure with no visible cause. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `installLivenessAnalyzer` | `static void installLivenessAnalyzer(TomHealthAnalyzer analyzer)` | Installs the process-wide liveness analyzer, logging the replacement at info with both runtime types. A function rather than a setter because the analyzer is a global anything in the process can replace at any moment, including mid-serving, and an assignment leaves no trace for a deployment to read. Not sealed after startup: the analyzer must be replaceable before the bean context exists, and the framework cannot know when a deployment has finished installing. |
| `installReadinessAnalyzer` | `static void installReadinessAnalyzer(TomHealthAnalyzer analyzer)` | The same for the readiness analyzer. |
| `resetHealthAnalyzers` | `static void resetHealthAnalyzers()` | Installs a fresh `TomDefaultHealthAnalyzer` on each probe — the state a new process starts in, one instance per probe. The supported way back for a test or an example; it logs like any other installation, because it is one. |
| `health` | `Future<Response> health()` | *(override)* Delegates to `livenessAnalyzer.analyzeHealth()` and hands the result to `responseFor`. |
| `ready` | `Future<Response> ready()` | *(override)* Delegates to `readinessAnalyzer.analyzeHealth()` and hands the result to `responseFor`. |
| `responseFor` | `static Response responseFor(TomHealthStatus status)` | The HTTP response one status is served as: `status.statusCode`, the message as the body, and `text/plain` — set here because a handler returning a `Response` bypasses the endpoint's `produces`. Public and static so a deployment writing its own health route answers with the same shape rather than a second spelling of it. |

## Enums

### TomHealthVerdict

Whether a deployment should be sent traffic. Two values, and deliberately not
three: HTTP offers a probe exactly two answers — send me traffic, or do not — so
a third verdict would either map to one of those two, making a distinction no
probe can act on, or invent a status code no orchestrator reads. Gradation
belongs in `TomHealthStatus.message`.

| Value | `statusCode` | Meaning |
| ----- | ------------ | ------- |
| `healthy` | `200` | Everything the analyzer checked answered. |
| `unhealthy` | `503` | Something did not. `503` is what takes a pod out of a load balancer and what a default probe already understands. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `statusCode` | `int` | The HTTP status a response carrying this verdict is answered with (final). |

## Global Functions and Constants

None — this module exposes no top-level functions or constants.
