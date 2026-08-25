# Health Check Module

A ready-made `GET /health` endpoint for an orchestrator's liveness probe. The
endpoint is public (no authentication) and unlogged, and returns a plain-text
status string produced by a pluggable `HealthAnalyzer` — `"OK"` by default, or
any descriptive string a custom analyzer returns.

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
- [Core Components](#core-components)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomHealthService` | reflected service | Declares the `GET /health` endpoint |
| `TomHealthServer` | reflected component | The default implementation; delegates to the analyzer |
| `HealthAnalyzer` | abstract class | The pluggable health-check contract (`analyzeHealth`) |
| `DefaultHealthAnalyzer` | class | The default analyzer; always returns `"OK"` |

## The /health Endpoint

`TomHealthService.health` is annotated as a `GET` endpoint at `/health` that
`produces` plain text, is marked `@TomPublicAccess` (so orchestration probes
reach it without a token), and sets `logRequests: false` so frequent probe
traffic does not flood the logs. Like every endpoint it is mounted by the
endpoints pipeline (see `doc/endpoints.md`) when the server starts.

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
string and have the two probes match different substrings of it. That matching
has to be on the body: every analyzer string is served with HTTP 200 (see
[Customizing the Health Check](#customizing-the-health-check)), so a probe
configured to look only at the status code cannot distinguish any two verdicts.

## Customizing the Health Check

The endpoint's body is delegated to a single global `HealthAnalyzer`. Replace it
before the server starts to add real checks:

```dart
class MyHealthAnalyzer extends HealthAnalyzer {
  @override
  Future<String> analyzeHealth() async {
    final dbOk = await checkDatabaseConnection();
    final cacheOk = await checkCacheService();
    if (dbOk && cacheOk) return 'OK';
    return 'DEGRADED: db=$dbOk, cache=$cacheOk';
  }
}

// Set globally before the server starts:
TomHealthServer.globalSettingsHealthAnalyzer = MyHealthAnalyzer();
```

The analyzer returns a free-form string: `"OK"` for healthy, anything else to
describe a degraded/unhealthy state. The endpoint returns whatever the analyzer
produces; mapping a status string to an HTTP status code (if desired) is a
caller/analyzer concern, not done by this module.

## How It Is Wired

`TomHealthServer` is annotated `@tomComponent` and implements the
`@tomService`-annotated `TomHealthService`, so the endpoints pipeline discovers
it by reflection, resolves its bean, and mounts the `/health` route — no manual
registration needed. The analyzer is a `static` field on `TomHealthServer`, so a
single assignment applies to every request.

## Core Components

- **`TomHealthService`** — the reflected service interface carrying the
  `GET /health` endpoint annotation.
- **`TomHealthServer`** — the reflected default implementation; holds the global
  `HealthAnalyzer` and delegates `health()` to it.
- **`HealthAnalyzer`** / **`DefaultHealthAnalyzer`** — the analyzer contract and
  its always-`"OK"` default.

## Dependencies

- `tom_core_kernel` — `tomReflector`, `TomHttpMethod`, `TomMimeType`.
- The endpoints module — `@tomService`, `@tomComponent`, `@TomEndpoint`,
  `@TomPublicAccess` (annotation discovery, routing, public access).
