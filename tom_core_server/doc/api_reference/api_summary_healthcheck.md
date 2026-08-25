# Tom Core Server API Reference: Health Check Module

Health-check service for server monitoring: a `GET /health` endpoint plus a
pluggable analyzer so applications can report custom health status to container
orchestration tools (Docker, Kubernetes).

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomHealthAnalyzer](#tomhealthanalyzer)
  - [TomDefaultHealthAnalyzer](#tomdefaulthealthanalyzer)
  - [TomHealthService](#tomhealthservice)
  - [TomHealthServer](#tomhealthserver)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tomserver/healthcheck/health_check.dart`.

`TomHealthService` is a `@tomService` interface declaring the `GET /health`
endpoint (public, unlogged). `TomHealthServer` is its `@tomComponent`
implementation; it delegates each request to the static `healthAnalyzer` and
returns that analyzer's string as the body, unchanged. Applications provide
custom logic by extending `TomHealthAnalyzer` (overriding `analyzeHealth`) and
assigning an instance to `TomHealthServer.healthAnalyzer` before startup; the
shipped `TomDefaultHealthAnalyzer` always returns `"OK"`.

Every analyzer string is served with HTTP 200 — this module does not map a
status to a status code, by design (see `doc/healthcheck.md`). A probe that
checks only for a 200 is therefore a liveness check, and stays green while a
custom analyzer answers `"DEGRADED: ..."`; acting on the verdict means reading
the body.

## Class Hierarchy

```
TomHealthAnalyzer  (abstract)
    └── TomDefaultHealthAnalyzer

TomHealthService  (abstract, @tomService)
    └── TomHealthServer  (@tomComponent, implements)
```

## Classes

### TomHealthAnalyzer

Analyzer for customizing health check responses. Extend and override
`analyzeHealth` to implement checks such as database connectivity, external
service availability, or resource usage.

- **Extends:** none (abstract base)

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `analyzeHealth` | `Future<String> analyzeHealth()` | Analyzes server health and returns a status string (`"OK"` when healthy, a descriptive message otherwise). |

### TomDefaultHealthAnalyzer

Default health analyzer that always returns `"OK"`.

- **Extends:** `TomHealthAnalyzer`

#### Constructors

```dart
TomDefaultHealthAnalyzer()
```

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `analyzeHealth` | `Future<String> analyzeHealth()` | *(override)* Always returns `"OK"`. |

### TomHealthService

Health check service interface for server health monitoring. Declares the
`GET /health` endpoint that container orchestration tools call to verify
availability. The response body is the installed `TomHealthAnalyzer`'s string
verbatim, so `"OK"` is the `TomDefaultHealthAnalyzer`'s answer rather than a
constant of the endpoint. Annotated `@tomReflector` / `@tomService`.

- **Extends:** none (abstract)

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `health` | `Future<String> health()` | The `GET /health` endpoint: returns a plain-text status string. Marked `@TomPublicAccess` and `logRequests: false`. |

### TomHealthServer

Default implementation of `TomHealthService`. Delegates health checks to
`healthAnalyzer`; set it to a custom `TomHealthAnalyzer` before server startup
for advanced logic. Annotated `@tomReflector` / `@tomComponent`.

- **Implements:** `TomHealthService`

#### Constructors

```dart
TomHealthServer()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `healthAnalyzer` | `static TomHealthAnalyzer` | Global health analyzer instance used by all health check requests (defaults to `TomDefaultHealthAnalyzer`). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `health` | `Future<String> health()` | *(override)* Delegates to `healthAnalyzer.analyzeHealth()`. |

## Global Functions and Constants

None — this module exposes no top-level functions or constants.
