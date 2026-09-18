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
- [The Certificate Policy](#the-certificate-policy)
- [Notes](#notes)
- [Dependencies](#dependencies)

---

## Overview

| Symbol | Kind | Purpose |
| ------ | ---- | ------- |
| `clientPlatformUtils` | getter | The platform utilities for the current Flutter target — one instance, built on first read |
| `TomBadCertificatePolicy` | final class | The hosts whose unverified TLS certificate the native client accepts |
| `resetClientPlatformUtils` | function | Discards the built instance so the next read constructs again; `@visibleForTesting` |

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

**One instance, built on first read**, for the current target. Every read
answers the same object. Platform predicates read Flutter's
`defaultTargetPlatform` / `kIsWeb` at call time, so caching the instance does not
freeze the answers — what is cached is the object, not what it reports.

It is a cache rather than a constant because the target is only known at run time
on the web branch and the constructor does real work on the native one: the
instance is built when something first asks for it, and not during library load
in a process that never uses it.

Two things follow, and both are worth having.

- **Identity means something.** A caller that reads the getter again instead of
  going through `TomPlatformUtils.current` holds what the process registered,
  not a second equal-looking object, so comparing platform-utils identities is
  not silently always false.
- **The native constructor's work happens once.** It copies the whole process
  environment into the kernel's env-var map; a getter that constructed per read
  paid for that on every read, on a call that looks like a property access.

`resetClientPlatformUtils()` discards the instance so the next read constructs
again. It is `@visibleForTesting` and exists for one reason: what a constructor
does can only be observed by a test that can get back to "nothing built yet" —
the same reason `TomConfigResourceProvider.clearAppConfigProvider` exists. It
unregisters nothing, so an instance already given to `setCurrentPlatform` stays
registered.

### `TomBadCertificatePolicy`

The hosts whose unverified TLS certificate the native client accepts — see
[The Certificate Policy](#the-certificate-policy).

## The Certificate Policy

A client handed a certificate it cannot verify normally refuses the connection,
and that refusal is the whole of TLS's value. Development against a local server
with a self-signed certificate is the one case where refusing helps nobody, so
the native variant's `badCertificateCallback` consults `TomBadCertificatePolicy`
and accepts the handshake for the hosts it names. A **loopback address is not
reachable from another machine**, so a certificate presented on one came from
this machine whatever it claims.

The shipped policy is `TomBadCertificatePolicy.defaultHosts`, and nothing else:

| Host | Why |
| ---- | --- |
| `localhost` | the name |
| `127.0.0.1` | the IPv4 loopback |
| `::1` | the IPv6 loopback |
| `[::1]` | the bracketed form an IPv6 literal carries in a URL |
| `0.0.0.0` | the unspecified address, which is how a server binding every interface is often addressed in development |

**Both loopback families are listed, and that is the point.** Which of them
`localhost` resolves to is the resolver's choice and differs between machines.
A policy naming one and not the other makes the same code, the same certificate
and the same URL succeed on one desktop and fail on the next — reported as a TLS
error, which sends the reader to audit the certificate rather than the address
family.

**`::1` is the spelling that arrives.** The callback is handed `Uri.host`, and
`Uri` strips the brackets: `https://[::1]:8443` resolves to a host of `::1`.
`[::1]` is listed anyway, for a caller that passes an authority where a host was
wanted; it costs nothing and covers the confusion.

### Changing it

`allowOnly` **replaces** the list, so an application can widen it or narrow it to
nothing:

```dart
// Trust no unverified certificate at all, not even on loopback.
TomBadCertificatePolicy.allowOnly(const []);

// A development container reached by name.
TomBadCertificatePolicy.allowOnly([
  ...TomBadCertificatePolicy.defaultHosts,
  'dev.internal',
]);
```

Matching is exact and case-sensitive on the host string — no patterns, no
wildcards — so an entry can only admit the one host it spells. A blank entry is
refused with an `ArgumentError`: no host string is empty, so an entry that is
names nothing, and it is what a split over a mis-typed setting leaves behind.
`reset()` puts the shipped policy back.

A replacement is **logged at warn level**, naming the hosts. A `const` list gave
one property a setter cannot — the policy in force was the policy in the source
— and the log line is what replaces it, so a widened boundary leaves a record
where an operator looks.

The policy is process-wide and read **per handshake**, so a client built before
a change obeys it too; hardening an application does not depend on the order its
clients happened to be created in. It is consulted **only on native targets**:
the browser performs its own validation and no application code can override it,
and the neutral variant creates no client at all.

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
- **The barrel exports three names: `clientPlatformUtils`,
  `TomBadCertificatePolicy` and the `@visibleForTesting`
  `resetClientPlatformUtils`.** The package barrel exports
  `platform_detection_client.dart`, and that file pulls in the selected variant
  with a conditional *import*, so `TomFlutterPlatformUtils` does not escape
  `src/`. It is documented — in
  [`api_summary_runtime.md`](api_reference/api_summary_runtime.md) — but it is
  **not part of the barrel's public API**, and a test that wants it has to
  import the variant file directly:

  ```dart
  import 'package:tom_core_flutter/src/tomclient/runtime/platform_detection_flutter_io.dart';
  ```

  Consumers never need the concrete type: `clientPlatformUtils` hands back a
  `TomPlatformUtils`, and the variant class is a different class on each target
  — three unrelated classes sharing a name, which is why the name exports no
  single type and the entry point uses `import` rather than `export`.

  `TomBadCertificatePolicy` is **exported**, and is a file of its own for that
  reason: an application has to be able to change it, and a policy declared
  inside the native variant could not be reached without a `dart:io` import that
  breaks the web build. It carries no platform dependency, so it exists on every
  target and exports unconditionally — consulted only where there is a TLS
  callback to consult it.
- **The three variants share a base and duplicate nothing.**
  The shared
  base holds ten members — `TomFlutterPlatformUtilsBase` in
  `platform_detection_base.dart` — namely the nine platform predicates (`isDesktop`, `isMobile`, `isWeb`,
  `isFuchsia`, `isWindows`, `isLinux`, `isMacOs`, `isAndroid`, `isIos`) and
  `getBrowserLocation()`. The variants **differ in four members**: `httpClient()`,
  `getIsolateName()`, `toString()` and — the web variant alone —
  `getBrowserLocation()`. Only the native variant declares a constructor.

  The base is a fourth file rather than a member of one variant because the
  conditional import requires all three to declare a class of the *same* name,
  so shared code has to sit in a differently-named class they all import
  unconditionally.

  Each of those ten bodies stood in triplicate until the base was drawn. The
  extraction had been deferred on the ground that the variants are
  compile-time-selected and cannot *all* be exercised from one host — true, and
  an argument for the base rather than against it. A conditional import means
  no host compiles more than one variant, so while each carried its own copy
  the other two copies were untested by construction. The base has no
  conditional import and is deliberately concrete, so one copy is instantiable
  and testable from any host; `runtime_test.dart`'s group *the shared
  predicates, exercised without a variant* drives it over every
  `TargetPlatform` Flutter declares.

  `getBrowserLocation()` reached the base for the same reason the predicates
  did: native and neutral both answered `null`. It answers `null` there — where
  `TomFallbackPlatformUtils` answers `""` — because a target that is not a
  browser has no location, and an empty string is a location that happens to be
  blank. The web variant is the one that has an answer, and overrides.

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
  certificate only for the hosts `TomBadCertificatePolicy` names, and rejects
  every other host — see [The Certificate Policy](#the-certificate-policy).
  The decision lives in the policy rather than in the callback because an
  `X509Certificate` has no public constructor and the callback is not readable
  back off the client, so a decision made inside it would be unreachable from a
  test.

---

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:io` | dart | `platform_detection_flutter_io.dart` | `HttpClient`, `Platform` |
| `dart:isolate` | dart | `platform_detection_flutter_io.dart` | `Isolate` |
| `fetch_client` | package | `platform_detection_web.dart` | the HTTP `Client` per target |
| `flutter` | package | `platform_detection_base.dart`, `platform_detection_client.dart` | `defaultTargetPlatform` / `kIsWeb` for the shared platform predicates; `@visibleForTesting` on `resetClientPlatformUtils` in the entry point. The three variants no longer import it — the members that read those symbols are all on the base |
| `http` | package | `platform_detection_flutter_io.dart`, `platform_detection_neutral.dart`, `platform_detection_web.dart` | the HTTP `Client` per target |
| `tom_core_kernel` | package | every file | The barrel each variant imports. It is the route to the contract, not its home — `tom_core_kernel.dart` re-exports the whole of `tom_basics`, where `TomPlatformUtils` and `TomFallbackPlatformUtils` are declared; `tom_core_kernel` declares neither type |
| `web` | package | `platform_detection_web.dart` | the HTTP `Client` per target |

- **`tom_basics`** (transitive): the contract these variants implement. Not a
  direct dependency of this package — it arrives through the kernel's
  re-export, which is why the import line in every variant names the kernel.
