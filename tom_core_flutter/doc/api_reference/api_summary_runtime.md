# Tom Core Flutter API Reference: Runtime Module

Compile-time platform selection for Flutter targets: a `TomPlatformUtils`
implementation chosen for native (`dart:io`), web (`dart:js`), or a neutral
fallback.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Exported Surface](#exported-surface)
- [Global Functions and Constants](#global-functions-and-constants)
  - [clientPlatformUtils](#clientplatformutils)
  - [resetClientPlatformUtils](#resetclientplatformutils)
- [Classes](#classes)
  - [TomBadCertificatePolicy](#tombadcertificatepolicy)
- [Internal Symbols (not exported)](#internal-symbols-not-exported)
  - [TomFlutterPlatformUtilsBase](#tomflutterplatformutilsbase--internal)
  - [TomFlutterPlatformUtils](#tomflutterplatformutils--internal)

## Overview

Source: `lib/src/tomclient/runtime/platform_detection_client.dart` (the exported
surface) plus the three compile-time variants
`platform_detection_flutter_io.dart`, `platform_detection_web.dart`, and
`platform_detection_neutral.dart`.

The exported entry point is the top-level getter `clientPlatformUtils`, which
answers **one** `TomPlatformUtils` per process — built on first read — whose
concrete type is selected at compile time by a conditional import: the native IO variant on desktop/mobile, the web
variant in the browser, or a neutral fallback. The instance answers platform
predicates (`isDesktop`, `isWeb`, `isAndroid`, …) and provides a
platform-appropriate HTTP `Client`. It is typically registered as the
process-wide platform at startup:

```dart
TomPlatformUtils.setCurrentPlatform(clientPlatformUtils);
```

## Class Hierarchy

```
TomPlatformUtils                     (tom_basics — the abstract contract)
    └── TomFallbackPlatformUtils     (tom_basics — neutral defaults)
            └── TomFlutterPlatformUtils   (one per compile-time variant: io / web / neutral)
```

Both base types are declared in `tom_basics`
(`lib/src/runtime/platform_neutral.dart`). They reach this module through the
`tom_core_kernel` barrel, which re-exports the whole of `tom_basics` — that is
why each variant's import line names the kernel even though the kernel declares
neither type. The contract's dartdoc, and the list of members an added
predicate has to override, are in `tom_basics`.

## Exported Surface

The package barrel exports exactly one file from this module —
`lib/tom_core_flutter.dart` exports
`src/tomclient/runtime/platform_detection_client.dart` — and that file reaches
the per-target variants with a conditional **`import`**, not an `export`. So
**`clientPlatformUtils` is the only symbol this module publishes.** Everything
else documented below lives in `src/` and is reachable only by importing a
variant file directly.

That is not an oversight to be corrected by adding an export.
`TomFlutterPlatformUtils` is three unrelated classes that happen to share a
name, one per target, so a conditional export of the selected variant would
export no single type.

The certificate policy is the exception that shows the rule. It is
application-facing — `TomBadCertificatePolicy` is how an application widens or
narrows which hosts may present an unverified certificate — so it cannot live
inside the native variant, where reaching it would need a `dart:io` import that
breaks the web build. It is a file of its own, carries no platform dependency,
exists on every target and is therefore exported unconditionally. Only the
native variant consults it.

To reach the internal symbols from a test on the native host:

```dart
import 'package:tom_core_flutter/src/tomclient/runtime/platform_detection_base.dart';
import 'package:tom_core_flutter/src/tomclient/runtime/platform_detection_flutter_io.dart';
```

The base compiles on every target, so the first of those two lines works from
any host; the second is the one that is native-only.

## Global Functions and Constants

### clientPlatformUtils

```dart
TomPlatformUtils get clientPlatformUtils
```

Answers the `TomPlatformUtils` for the current Flutter target (concrete type
selected at compile time). **One instance per process**, built on first read;
every read returns the same object.

A cache rather than a constant, because the target is only known at run time on
the web branch and the constructor does real work on the native one — so the
instance is built when something first asks for it, not during library load in a
process that never uses it. Caching the object does not freeze what it reports:
every platform predicate reads `defaultTargetPlatform` / `kIsWeb` at call time.

Two consequences. Identity is meaningful — a caller that reads the getter again
rather than going through `TomPlatformUtils.current` holds what the process
registered, so comparing platform-utils identities is not silently always false.
And the native constructor's work happens once: it copies the whole process
environment into the kernel's env-var map, which a getter that constructed per
read paid for on every read.

### resetClientPlatformUtils

```dart
@visibleForTesting
void resetClientPlatformUtils()
```

Discards the built instance, so the next read of `clientPlatformUtils`
constructs a new one. Exists because the construction is otherwise one-way: what
a constructor does can only be observed by a test that can get back to "nothing
built yet" — the same reason `TomConfigResourceProvider.clearAppConfigProvider`
exists. It unregisters nothing; an instance already handed to
`TomPlatformUtils.setCurrentPlatform` stays registered.

## Classes

### TomBadCertificatePolicy

Source: `lib/src/tomclient/runtime/bad_certificate_policy.dart`. Exported.

The hosts whose **unverified** TLS certificate the native HTTP client accepts.
The native variant's `HttpClient.badCertificateCallback` delegates to it; the
web target performs its own validation and the neutral variant builds no client,
so on those two the policy is present and never consulted.

Not instantiable — the policy is process-wide, and a second instance would
suggest two policies could be in force.

#### Static members

| Member | Signature | Description |
| ------ | --------- | ----------- |
| `defaultHosts` | `static const List<String>` | The shipped policy: `0.0.0.0`, `localhost`, `127.0.0.1`, `::1`, `[::1]` — and nothing else. `const`, so the policy an application ships with is auditable by reading one declaration. |
| `hosts` | `static List<String> get` | The hosts currently accepted, **unmodifiable**: the list is the policy, and a caller that could add to what it read would widen a security boundary without passing through `allowOnly`. |
| `allows` | `static bool allows(String host)` | Whether an unverified certificate is accepted for `host`. Exact, case-sensitive match — no patterns and no wildcards, so an entry admits only the host it spells. |
| `allowOnly` | `static void allowOnly(Iterable<String> allowed)` | **Replaces** the list. An empty `allowed` is legitimate and means "accept no unverified certificate". A blank entry is refused with `ArgumentError`, and refused before anything takes effect. Logs at warn level, naming the hosts. |
| `reset` | `static void reset()` | Restores `defaultHosts`. |

**Both loopback families are in the default, and that is the entry that
matters.** Which of them `localhost` resolves to is the resolver's choice and
differs between machines, so a policy naming one and not the other makes the
same code, certificate and URL succeed on one desktop and fail on the next —
reported as a TLS error, which sends the reader to audit the certificate rather
than the address family.

**`::1` is the spelling that arrives.** The callback is handed `Uri.host`, and
`Uri` strips the brackets, so `https://[::1]:8443` resolves to a host of `::1`.
`[::1]` is listed anyway for a caller that passes an authority where a host was
wanted.

**A replacement is logged** because a `const` list gave one property a setter
cannot: the policy in force was the policy in the source. The log line is what
replaces it, so a widened boundary leaves a record where an operator looks.

The policy is read **per handshake**, not captured when a client is built, so a
narrowing takes effect on clients that already exist — hardening does not depend
on the order clients happened to be created in.

## Internal Symbols (not exported)

Documented because they carry behaviour worth knowing about, not because they
can be called through the barrel. Both require a direct `src/` import as shown
above.

### TomFlutterPlatformUtilsBase — internal

Source: `lib/src/tomclient/runtime/platform_detection_base.dart`.

What every variant answers the same way: the nine platform predicates read from
Flutter's `defaultTargetPlatform` / `kIsWeb`, and `getBrowserLocation()`. All
three `TomFlutterPlatformUtils` variants extend it.

- **Extends:** `TomFallbackPlatformUtils`

| Member | Signature | Description |
| ------ | --------- | ----------- |
| `isDesktop` | `bool isDesktop()` | Target is windows, linux or macOS. |
| `isMobile` | `bool isMobile()` | Target is android or iOS. |
| `isWeb` | `bool isWeb()` | The **build** is a web build (`kIsWeb`) — the one member that does not read the target, so it does not move when the target does. |
| `isFuchsia` / `isWindows` / `isLinux` / `isMacOs` / `isAndroid` / `isIos` | `bool …()` | Target is that platform. Exactly one of the six answers `true` for any target. |
| `getBrowserLocation` | `String? getBrowserLocation()` | `null` — where `TomFallbackPlatformUtils` answers `""`, because a target that is not a browser has no location and an empty string is a location that happens to be blank. The web variant overrides it. |

A fourth file rather than a member of one variant: the conditional import
requires all three variants to declare a class of the *same* name, so shared
code has to sit in a differently-named class they all import unconditionally.

**Deliberately concrete**, and that is the point of extracting it. A conditional
import means no host compiles more than one variant, so while each variant
carried its own copy of these bodies the other two copies were untested by
construction. One copy on a class with no conditional import can be
instantiated and driven over every `TargetPlatform` from any host. What it does
not answer it inherits — `httpClient()` throws, because which client to build is
exactly what the variants exist to decide.

### TomFlutterPlatformUtils — internal

The Flutter `TomPlatformUtils` implementation. **Three source variants share
this name**, one per compile-time target; the conditional import in
`platform_detection_client.dart` picks exactly one. All three extend
`TomFlutterPlatformUtilsBase`; that shared base holds ten members — the nine
platform predicates read from Flutter's `defaultTargetPlatform` / `kIsWeb`, plus
`getBrowserLocation()`. The variants **differ in four members**: `httpClient()`,
`getIsolateName()`, `toString()` and — the web variant alone —
`getBrowserLocation()`. Only the native variant declares a constructor.

The name is **not exported**, and could not usefully be: it denotes a different
class on each target. Consumers hold the instance as its supertype
`TomPlatformUtils`, which is what `clientPlatformUtils` returns; the concrete
type is an implementation detail and is named here only so the per-variant
behaviour below has something to hang on.

- **Extends:** `TomFlutterPlatformUtilsBase` (internal, above)

| Variant | `httpClient()` | `getBrowserLocation()` | Notes |
| ------- | -------------- | ---------------------- | ----- |
| `flutter_io` (native) | `IOClient`, with `badCertificateCallback` delegating to `TomBadCertificatePolicy`. **Every** native target shares it, Apple ones included — `cupertino_http`'s `URLSession`-backed `CupertinoClient` was considered and declined: a native-plugin dependency and a second HTTP path no Linux or Windows host can exercise, for a benefit no consumer needs today. If an Apple target appears the shape is a runtime branch on `defaultTargetPlatform` here, not a fourth compile-time variant, because `dart:io` exists on iOS and macOS. | inherited | Imports the process environment into the `tom_basics` env-var map (`getTomEnvVars()`) at construction. |
| `web` | `FetchClient(mode: RequestMode.cors)` | `window.location.href` | — |
| `neutral` | throws `UnsupportedError` | inherited | Fallback when neither `dart:io` nor `dart:js` is available. The refusal is permanent — such a target has no client implementation to construct. |

#### Constructors

```dart
TomFlutterPlatformUtils()
```

#### Methods

Every "True on …" below means the *Flutter target* is that platform, read from
`defaultTargetPlatform` at call time — not the machine the process is running
on. The two coincide on a device and part company under `flutter test`, whose
target is `TargetPlatform.android` regardless of host. See
[`runtime.md`](../runtime.md) for what that implies for tests and diagnostics.

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `isDesktop` | `bool isDesktop()` | *(override)* True on Windows/Linux/macOS. |
| `isMobile` | `bool isMobile()` | *(override)* True on Android/iOS. |
| `isWeb` | `bool isWeb()` | *(override)* Value of `kIsWeb`. |
| `isFuchsia` | `bool isFuchsia()` | *(override)* True on Fuchsia. |
| `isWindows` | `bool isWindows()` | *(override)* True on Windows. |
| `isLinux` | `bool isLinux()` | *(override)* True on Linux. |
| `isMacOs` | `bool isMacOs()` | *(override)* True on macOS. |
| `isAndroid` | `bool isAndroid()` | *(override)* True on Android. |
| `isIos` | `bool isIos()` | *(override)* True on iOS. |
| `out` | `void out(String s)` | *(inherited from `TomFallbackPlatformUtils`)* Prints `s` to standard output. |
| `outError` | `void outError(String s)` | *(inherited from `TomFallbackPlatformUtils`)* Prints `s` to standard output, the same destination as `out` — the two are named apart but not routed apart. |
| `httpClient` | `Client httpClient()` | *(override)* A platform-appropriate HTTP client (see the variant table). |
| `getBrowserLocation` | `String? getBrowserLocation()` | *(override)* The browser location URL, or `null` off the web. |
| `getIsolateName` | `String getIsolateName()` | *(override)* A short **label** for the current isolate, not an identifier — native answers the isolate's `debugName` (or `"main"` when it reports none), web the constant `"web"`, neutral the constant `"neutral"`. `Isolate.spawn` defaults `debugName` to the entry point's function name, so several isolates spawned from one entry point share a name; an explicit `debugName` discriminates, and the kernel's `TomWorkerPool` passes one per worker. See `doc/runtime.md` §The Isolate Name. |
| `toString` | `String toString()` | *(override)* Identifies the active variant. |
