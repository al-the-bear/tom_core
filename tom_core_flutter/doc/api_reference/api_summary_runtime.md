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
- [Internal Symbols (not exported)](#internal-symbols-not-exported)
  - [allowsBadCertificateForHost](#allowsbadcertificateforhost--internal)
  - [TomFlutterPlatformUtils](#tomflutterplatformutils--internal)

## Overview

Source: `lib/src/tomclient/runtime/platform_detection_client.dart` (the exported
surface) plus the three compile-time variants
`platform_detection_flutter_io.dart`, `platform_detection_web.dart`, and
`platform_detection_neutral.dart`.

The exported entry point is the top-level getter `clientPlatformUtils`, which
returns a fresh `TomPlatformUtils` whose concrete type is selected at compile
time by a conditional import: the native IO variant on desktop/mobile, the web
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
`lib/tom_core_flutter.dart:21` exports
`src/tomclient/runtime/platform_detection_client.dart` — and that file reaches
the per-target variants with a conditional **`import`**, not an `export`. So
**`clientPlatformUtils` is the only symbol this module publishes.** Everything
else documented below lives in `src/` and is reachable only by importing a
variant file directly.

That is not an oversight to be corrected by adding an export. A conditional
export would have to name a symbol that exists on *every* target, and
`allowsBadCertificateForHost` is meaningful only where there is a TLS callback
to configure — the web and neutral variants have none. `TomFlutterPlatformUtils`
is likewise three unrelated classes that happen to share a name, one per target,
so the name denotes no single exportable type.

To reach the internal symbols from a test on the native host:

```dart
import 'package:tom_core_flutter/src/tomclient/runtime/platform_detection_flutter_io.dart';
```

## Global Functions and Constants

### clientPlatformUtils

```dart
TomPlatformUtils get clientPlatformUtils
```

Returns a fresh `TomPlatformUtils` for the current Flutter target (concrete type
selected at compile time). This is the module's entire exported surface.

## Internal Symbols (not exported)

Documented because they carry behaviour worth knowing about — the certificate
policy in particular — not because they can be called through the barrel. Both
require the direct `src/` import shown above.

### allowsBadCertificateForHost — internal

```dart
bool allowsBadCertificateForHost(String host)
```

*(native IO variant only)* Whether a TLS handshake with a bad certificate is
tolerated for `host`. Only loopback hosts (`0.0.0.0`, `localhost`,
`127.0.0.1`) are allowed; every other host is rejected. Exposed at the top level
of its file so the decision can be unit-tested directly — an `X509Certificate`
has no public constructor and `HttpClient.badCertificateCallback` is not
readable back off the client, so the policy is otherwise unreachable from a
test. It is **not exported**; it is declared only in
`platform_detection_flutter_io.dart`.

### TomFlutterPlatformUtils — internal

The Flutter `TomPlatformUtils` implementation. **Three source variants share
this name**, one per compile-time target; the conditional import in
`platform_detection_client.dart` picks exactly one. All three report platform
predicates from Flutter's `defaultTargetPlatform` / `kIsWeb`; they differ in how
they provide an HTTP `Client` and read the browser location.

The name is **not exported**, and could not usefully be: it denotes a different
class on each target. Consumers hold the instance as its supertype
`TomPlatformUtils`, which is what `clientPlatformUtils` returns; the concrete
type is an implementation detail and is named here only so the per-variant
behaviour below has something to hang on.

- **Extends:** `TomFallbackPlatformUtils`

| Variant | `httpClient()` | `getBrowserLocation()` | Notes |
| ------- | -------------- | ---------------------- | ----- |
| `flutter_io` (native) | `IOClient` (bad-cert allowed for loopback only) | `null` | Imports the process environment into the `tom_basics` env-var map (`getTomEnvVars()`) at construction. |
| `web` | `FetchClient(mode: RequestMode.cors)` | `window.location.href` | — |
| `neutral` | throws `UnimplementedError` | `null` | Fallback when neither `dart:io` nor `dart:js` is available. |

#### Constructors

```dart
TomFlutterPlatformUtils()
```

#### Methods

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
| `out` | `void out(String s)` | *(override)* Prints `s` to standard output. |
| `outError` | `void outError(String s)` | *(override)* Prints `s` to standard output, the same destination as `out` — the two are named apart but not routed apart. |
| `httpClient` | `Client httpClient()` | *(override)* A platform-appropriate HTTP client (see the variant table). |
| `getBrowserLocation` | `String? getBrowserLocation()` | *(override)* The browser location URL, or `null` off the web. |
| `getIsolateName` | `String getIsolateName()` | *(override)* A short name for the current isolate. |
| `toString` | `String toString()` | *(override)* Identifies the active variant. |
