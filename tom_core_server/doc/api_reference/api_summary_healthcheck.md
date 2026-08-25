# Tom Core Server API Reference: Health Check Module

Health-check service for server monitoring: a `GET /health` endpoint plus a
pluggable analyzer so applications can report custom health status to container
orchestration tools (Docker, Kubernetes).

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [HealthAnalyzer](#healthanalyzer)
  - [DefaultHealthAnalyzer](#defaulthealthanalyzer)
  - [TomHealthService](#tomhealthservice)
  - [TomHealthServer](#tomhealthserver)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tomserver/healthcheck/health_check.dart`.

`TomHealthService` is a `@tomService` interface declaring the `GET /health`
endpoint (public, unlogged). `TomHealthServer` is its `@tomComponent`
implementation; it delegates each request to the static
`globalSettingsHealthAnalyzer` and returns that analyzer's string as the body,
unchanged. Applications provide custom logic by extending `HealthAnalyzer`
(overriding `analyzeHealth`) and assigning an instance to
`TomHealthServer.globalSettingsHealthAnalyzer` before startup; the shipped
`DefaultHealthAnalyzer` always returns `"OK"`.

Every analyzer string is served with HTTP 200 — this module does not map a
status to a status code, by design (see `doc/healthcheck.md`). A probe that
checks only for a 200 is therefore a liveness check, and stays green while a
custom analyzer answers `"DEGRADED: ..."`; acting on the verdict means reading
the body.

## Class Hierarchy

```
HealthAnalyzer  (abstract)
    └── DefaultHealthAnalyzer

TomHealthService  (abstract, @tomService)
    └── TomHealthServer  (@tomComponent, implements)
```

## Classes

### HealthAnalyzer

Analyzer for customizing health check responses. Extend and override
`analyzeHealth` to implement checks such as database connectivity, external
service availability, or resource usage.

- **Extends:** none (abstract base)

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `analyzeHealth` | `Future<String> analyzeHealth()` | Analyzes server health and returns a status string (`"OK"` when healthy, a descriptive message otherwise). |

### DefaultHealthAnalyzer

Default health analyzer that always returns `"OK"`.

- **Extends:** `HealthAnalyzer`

#### Constructors

```dart
DefaultHealthAnalyzer()
```

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `analyzeHealth` | `Future<String> analyzeHealth()` | *(override)* Always returns `"OK"`. |

### TomHealthService

Health check service interface for server health monitoring. Declares the
`GET /health` endpoint that container orchestration tools call to verify
availability. The response body is the installed `HealthAnalyzer`'s string
verbatim, so `"OK"` is the `DefaultHealthAnalyzer`'s answer rather than a
constant of the endpoint. Annotated `@tomReflector` / `@tomService`.

- **Extends:** none (abstract)

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `health` | `Future<String> health()` | The `GET /health` endpoint: returns a plain-text status string. Marked `@TomPublicAccess` and `logRequests: false`. |

### TomHealthServer

Default implementation of `TomHealthService`. Delegates health checks to
`globalSettingsHealthAnalyzer`; set it to a custom `HealthAnalyzer` before server
startup for advanced logic. Annotated `@tomReflector` / `@tomComponent`.

- **Implements:** `TomHealthService`

#### Constructors

```dart
TomHealthServer()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `globalSettingsHealthAnalyzer` | `static HealthAnalyzer` | Global health analyzer instance used by all health check requests (defaults to `DefaultHealthAnalyzer`). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `health` | `Future<String> health()` | *(override)* Delegates to `globalSettingsHealthAnalyzer.analyzeHealth()`. |

## Global Functions and Constants

None — this module exposes no top-level functions or constants.
