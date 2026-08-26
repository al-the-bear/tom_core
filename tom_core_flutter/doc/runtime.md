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
| neither | neutral fallback | throws `UnsupportedError` — must pick a concrete variant |

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

- **The predicates answer about the Flutter *target*, not the host machine.**
  All nine read `defaultTargetPlatform` (or `kIsWeb`), so what they report is
  what the build is targeting. On a device the two coincide. Under
  `flutter test` they do not: `defaultTargetPlatform` is
  `TargetPlatform.android` whatever machine the harness runs on, so a developer
  on macOS sees `isDesktop=false isMobile=true`. That is the module working,
  not failing.

  Two consequences worth keeping in mind. A test that asserts a predicate
  without pinning the target is really asserting the harness default — set
  `debugDefaultTargetPlatformOverride` per case, as this module's own suite
  does. And a diagnostic that prints a predicate should print the target beside
  it, as [the runtime example](../example/runtime/runtime_example.dart) does,
  or the answer arrives without its cause.

  There is also no target for which `isDesktop() || isMobile()` is guaranteed:
  Fuchsia belongs to neither family.
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
- The three `TomFlutterPlatformUtils` implementations override thirteen members
  each and **duplicate nine members verbatim** — the platform predicates
  (`isDesktop`, `isMobile`, `isWeb`, `isFuchsia`, `isWindows`, `isLinux`,
  `isMacOs`, `isAndroid`, `isIos`). They differ in four: `httpClient()`,
  `getBrowserLocation()`, `getIsolateName()` and `toString()`. Only the native
  variant declares a constructor.

  `getBrowserLocation()` is the weakest of the four differences — native and
  neutral both return `null`, so only the web variant actually diverges.

  The duplication is a known candidate for extracting a shared base, deferred
  because the variants are compile-time-selected and cannot *all* be exercised
  from one host. Two of the three can: `flutter_io` and `neutral` both import
  only Flutter, `http` and the kernel, so a test on the VM can import either
  directly — with a prefix, since they share a class name — and call it. Only
  `web` is out of reach, because `package:web` needs JS interop the VM cannot
  provide.

  Console output is not part of it. `out` and `outError` are declared in no
  variant: they come from `TomFallbackPlatformUtils`, which already prints to
  standard output, so there is nothing per-target to say about them. A variant
  that wants to route them elsewhere overrides them; one that does not, does
  not.
- The neutral fallback cannot create an HTTP client — `httpClient()` throws
  `UnsupportedError`. Register a concrete variant (which `clientPlatformUtils`
  does automatically on IO/web targets) before performing network calls.

  `UnsupportedError` and not `UnimplementedError`: nothing is waiting to be
  written here. A target that exposes neither `dart:io` nor `dart:js` has no
  client implementation to construct, so the refusal is permanent rather than
  pending. The distinction is easy to lose in a test, because `dart:core`
  declares `UnimplementedError implements UnsupportedError` — an assertion that
  only checks for the supertype accepts either.
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
