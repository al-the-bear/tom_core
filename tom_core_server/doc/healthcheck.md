# Health Check Module

A ready-made `GET /health` endpoint for an orchestrator's liveness probe. The
endpoint is public (no authentication) and unlogged, and returns a plain-text
status string produced by a pluggable `TomHealthAnalyzer` — `"OK"` by default,
or any descriptive string a custom analyzer returns.

One endpoint, one process-wide analyzer, one verdict. Liveness ("am I running")
and readiness ("can I serve traffic") cannot be answered separately, so this is
not a readiness endpoint — see
[One Verdict for the Process](#one-verdict-for-the-process).

## Table of Contents

- [Overview](#overview)
- [The /health Endpoint](#the-health-endpoint)
- [One Verdict for the Process](#one-verdict-for-the-process)
- [Customizing the Health Check](#customizing-the-health-check)
- [How It Is Wired](#how-it-is-wired)
- [Not Yet Implemented](#not-yet-implemented)
- [Verification](#verification)
- [Core Components](#core-components)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomHealthService` | abstract class | Declares the `GET /health` endpoint |
| `TomHealthServer` | class | The default implementation; delegates to the analyzer |
| `TomHealthAnalyzer` | abstract class | The pluggable health-check contract (`analyzeHealth`) |
| `TomHealthStatus` | class | What an analyzer concluded: a verdict a probe acts on, and a message a human reads |
| `TomHealthVerdict` | enum | `healthy` (200) or `unhealthy` (503) — the two answers HTTP offers a probe |
| `TomDefaultHealthAnalyzer` | class | The default analyzer; always reports healthy |

## The /health Endpoint

`TomHealthService.health` is annotated as a `GET` endpoint at `/health` that
`produces` plain text, is marked `@TomPublicAccess` (so orchestration probes
reach it without a token), and sets `logRequests: false` so frequent probe
traffic does not flood the logs. Like every endpoint it is mounted by the
endpoints pipeline (see `doc/endpoints.md`) when the server starts.

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

## One Verdict for the Process

There is one route, one static analyzer and therefore one answer. Point an
orchestrator's **liveness** probe at it.

It is not a readiness endpoint. Liveness ("am I running") and readiness ("can I
serve traffic") are different questions with opposite consequences — a failing
readiness probe takes the pod out of the load balancer, while a failing liveness
probe restarts it — and this module cannot tell them apart, because the single
analyzer produces one string for both.

So a deployment that points both probes at `/health` gets the same verdict twice
and has to choose which consequence it wants:

- if the analyzer reports unhealthy while the process is merely *not yet ready*
  — still warming a cache, still opening a pool — the liveness probe restarts a
  pod that would have recovered on its own, and the restart loop is indefinite
  because a restart does not make the dependency come back;
- if the analyzer stays `"OK"` through that state so liveness is safe, then the
  readiness probe reports ready too early and traffic arrives before the process
  can serve it.

A deployment that needs both answers today has to encode both into the one
verdict and accept that both probes act on it: an unhealthy answer is a `503`,
which takes the pod out of the load balancer *and* restarts it. Splitting them
needs a second route with a second analyzer, which this module does not have.

## Customizing the Health Check

The endpoint's body is delegated to a single global `TomHealthAnalyzer`.
Replace it before the server starts to add real checks:

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

// Set globally before the server starts:
TomHealthServer.healthAnalyzer = MyHealthAnalyzer();
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

## How It Is Wired

`TomHealthServer` is annotated `@tomComponent` and implements the
`@tomService`-annotated `TomHealthService`, so the endpoints pipeline discovers
it by reflection, resolves its bean, and mounts the `/health` route — no manual
registration needed. The analyzer is a `static` field on `TomHealthServer`, so a
single assignment applies to every request.

## Not Yet Implemented

- **There is no readiness endpoint, only a liveness one.** One route, one
  analyzer, one answer for two questions with opposite consequences —
  [One Verdict for the Process](#one-verdict-for-the-process) sets out what that
  costs a deployment that needs both, which is that an unhealthy verdict both
  takes the pod out of the load balancer and restarts it.
- **The analyzer is process-wide.** `TomHealthServer.healthAnalyzer` is
  `static`, so one assignment answers every request on every isolate; there is
  no per-instance, per-port or per-request override. A deployment that wants two
  different checks needs two processes.
- **`analyzeHealth` is awaited with no deadline.** An analyzer that probes a
  database and hangs hangs the `/health` request, which is the request an
  orchestrator uses to decide whether the process is alive — so a slow
  dependency reads as a dead process and earns a restart. An analyzer that
  touches anything remote should impose its own timeout and answer degraded.

## Verification

`test/healthcheck_test.dart` covers the surface a deployment drives directly:
`TomDefaultHealthAnalyzer`'s verdict, `TomHealthServer.health` delegating to
whichever analyzer is installed, and the declared route. The *mounted* route is
a different claim — it is produced by the reflection-based endpoints pipeline —
so it is asserted where that pipeline runs, in
`test/endpoints_pipeline_test.dart`, in the group named
`healthcheck GET /health route`.

```bash
dart run example/healthcheck/healthcheck_example.dart
```

`example/healthcheck/healthcheck_example.dart` shows the analyzer seam without
the router, deliberately: mounting the route means initializing generated
reflection and building a pipeline, which would bury the one thing the example
is about. Every step checks its own result, and `test/examples_test.dart` runs
it.

## Core Components

- **`TomHealthService`** — the reflected service interface carrying the
  `GET /health` endpoint annotation.
- **`TomHealthServer`** — the reflected default implementation; holds the global
  `TomHealthAnalyzer`, delegates `health()` to it, and turns the verdict into
  the response with `responseFor`.
- **`TomHealthAnalyzer`** / **`TomDefaultHealthAnalyzer`** — the analyzer
  contract and its always-healthy default.
- **`TomHealthStatus`** / **`TomHealthVerdict`** — what an analyzer concludes:
  the verdict that decides the status code, and the message served as the body.

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `shelf` | package | `health_check.dart` | `Response`, because the status code is part of the answer and a `String` has nowhere to put it |
| `tom_core_kernel` | package | every file | `tomReflector` (reflection), `tomComponent` (the bean locator's component annotation), `TomPublicAccess` (an access control), `TomHeader` (the `Content-Type` name), and `TomHttpMethod` / `TomMimeType` (the HTTP vocabulary the endpoint annotation is written in) |
| [endpoints](endpoints.md) | module | every file | `tomService` and `TomEndpoint`, the two annotations by which the endpoints pipeline discovers the route |

`health_check.dart` imports exactly two things, and between them they supply
every symbol it uses:

Note that `@tomComponent` and `@TomPublicAccess` are *kernel* annotations even
though the endpoints pipeline is what acts on them: the pipeline resolves the
component's bean and enforces the access control, but neither symbol belongs to
the endpoints module.
