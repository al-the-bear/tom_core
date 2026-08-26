# Runtime Module

Flutter platform detection. Exposes a single entry point —
`clientPlatformUtils` — that yields a `TomPlatformUtils` whose concrete
implementation is chosen **at compile time** for the current target (native IO,
web, or a neutral fallback).

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [How the Variant Is Selected](#how-the-variant-is-selected)
- [Core Components](#core-components)
- [Notes](#notes)
- [Dependencies](#dependencies)

---

## Overview

| Symbol | Kind | Purpose |
| ------ | ---- | ------- |
| `clientPlatformUtils` | getter → `TomPlatformUtils` | The platform utilities for the current Flutter target |

The returned object answers platform predicates (`isDesktop`, `isMobile`,
`isWeb`, `isWindows`, `isLinux`, `isMacOs`, `isAndroid`, `isIos`, `isFuchsia`),
provides a platform-appropriate HTTP `Client` via `httpClient()`, and reports
the isolate name and (on web) the browser location.

## Quick Start

```dart
import 'package:tom_core_flutter/tom_core_flutter.dart';

// Register the platform-appropriate utilities process-wide at startup:
TomPlatformUtils.setCurrentPlatform(clientPlatformUtils);

final p = clientPlatformUtils;
if (p.isDesktop()) {
  // desktop-only behaviour
}
final client = p.httpClient(); // IOClient natively, FetchClient on web
```

## How the Variant Is Selected

`clientPlatformUtils` returns `TomFlutterPlatformUtils()`, but *which*
`TomFlutterPlatformUtils` is resolved by a conditional import:

| Available library | Implementation | HTTP client |
| ----------------- | -------------- | ----------- |
| `dart:io` | native (desktop / mobile) | `IOClient` (localhost-permissive certs) |
| `dart:js` | web (browser) | `FetchClient` (CORS) |
| neither | neutral fallback | throws — must pick a concrete variant |

The native variant additionally imports the process environment into the
`tom_basics` env-var map (`getTomEnvVars()`, inherited from
`TomFallbackPlatformUtils`) at construction; the web variant exposes the browser
location.

## Core Components

### `clientPlatformUtils`

The sole public symbol. Each read constructs a fresh `TomPlatformUtils` for the
current target. Platform predicates read Flutter's `defaultTargetPlatform` /
`kIsWeb` at call time.

## Notes

- **`clientPlatformUtils` is the only symbol the barrel exports.** The package
  barrel exports `platform_detection_client.dart`, and that file pulls in the
  selected variant with a conditional *import*, so neither
  `TomFlutterPlatformUtils` nor `allowsBadCertificateForHost` escapes `src/`.
  Both are documented — in
  [`api_summary_runtime.md`](api_reference/api_summary_runtime.md) — but a test
  that wants them has to import the variant file directly:

  ```dart
  import 'package:tom_core_flutter/src/tomclient/runtime/platform_detection_flutter_io.dart';
  ```

  Consumers never need the concrete type: `clientPlatformUtils` hands back a
  `TomPlatformUtils`, and the variant class is a different class on each target.
- The three `TomFlutterPlatformUtils` implementations share identical platform
  predicate logic; they differ only in construction, `httpClient()`,
  `getBrowserLocation()`, and `getIsolateName()`. The duplication is a known
  candidate for extracting a shared base, deferred because the variants are
  compile-time-selected and cannot all be exercised from one host.
- The neutral fallback cannot create an HTTP client — `httpClient()` throws.
  Register a concrete variant (which `clientPlatformUtils` does automatically on
  IO/web targets) before performing network calls.
- The native `IOClient`'s `badCertificateCallback` tolerates a bad TLS
  certificate **only** for loopback hosts (`0.0.0.0`, `localhost`,
  `127.0.0.1`) and rejects every other host. The decision is the top-level
  `allowsBadCertificateForHost(host)` in `platform_detection_flutter_io.dart`
  — a testability hook (an `X509Certificate` has no public constructor and the
  callback is not readable off the client), not part of the barrel's public
  API.

---

## Dependencies

- **`tom_core_kernel`** (direct): the barrel each variant imports. It is the
  route to the contract, not its home — `tom_core_kernel.dart` re-exports the
  whole of `tom_basics`, which is where `TomPlatformUtils` and
  `TomFallbackPlatformUtils` are actually declared
  (`lib/src/runtime/platform_neutral.dart`). Read the contract's dartdoc there,
  and look there for what a new predicate has to override; `tom_core_kernel`
  declares neither type.
- **`tom_basics`** (transitive): the contract these variants implement. Not a
  direct dependency of this package — it arrives through the kernel's
  re-export, which is why the import line in every variant names the kernel.
- **`flutter`**: `defaultTargetPlatform` / `kIsWeb` for platform predicates.
- **`http`** (+ `fetch_client` / `web` on web): the HTTP `Client` per target.
