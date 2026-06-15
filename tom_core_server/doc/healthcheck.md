# Health Check Module

A ready-made `GET /health` endpoint for liveness/readiness probes. The endpoint
is public (no authentication) and unlogged, and returns a plain-text status
string produced by a pluggable [HealthAnalyzer] — `"OK"` by default, or any
descriptive string a custom analyzer returns.

## Table of Contents

- [Overview](#overview)
- [The /health Endpoint](#the-health-endpoint)
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

## Customizing the Health Check

The endpoint's body is delegated to a single global [HealthAnalyzer]. Replace it
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
