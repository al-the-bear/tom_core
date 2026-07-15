# Tom Core Flutter API Reference: Runtime Module

Compile-time platform selection for Flutter targets: a `TomPlatformUtils`
implementation chosen for native (`dart:io`), web (`dart:js`), or a neutral
fallback.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Global Functions and Constants](#global-functions-and-constants)
  - [clientPlatformUtils](#clientplatformutils)
  - [allowsBadCertificateForHost](#allowsbadcertificateforhost)
- [Classes](#classes)
  - [TomFlutterPlatformUtils](#tomflutterplatformutils)

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
TomFallbackPlatformUtils  (kernel)
    └── TomFlutterPlatformUtils   (one per compile-time variant: io / web / neutral)
```

## Global Functions and Constants

### clientPlatformUtils

```dart
TomPlatformUtils get clientPlatformUtils
```

Returns a fresh `TomPlatformUtils` for the current Flutter target (concrete type
selected at compile time). This is the module's primary public surface.

### allowsBadCertificateForHost

```dart
bool allowsBadCertificateForHost(String host)
```

*(native IO variant only)* Whether a TLS handshake with a bad certificate is
tolerated for `host`. Only loopback hosts (`0.0.0.0`, `localhost`,
`127.0.0.1`) are allowed; every other host is rejected. Exposed at the top level
so the decision can be unit-tested directly.

## Classes

### TomFlutterPlatformUtils

The Flutter `TomPlatformUtils` implementation. **Three source variants share
this name**, one per compile-time target; the conditional import in
`platform_detection_client.dart` picks exactly one. All three report platform
predicates from Flutter's `defaultTargetPlatform` / `kIsWeb`; they differ in how
they provide an HTTP `Client` and read the browser location.

- **Extends:** `TomFallbackPlatformUtils`

| Variant | `httpClient()` | `getBrowserLocation()` | Notes |
| ------- | -------------- | ---------------------- | ----- |
| `flutter_io` (native) | `IOClient` (bad-cert allowed for loopback only) | `null` | Imports the process environment into the kernel env vars at construction. |
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
| `outError` | `void outError(String s)` | *(override)* Prints `s` as an error. |
| `httpClient` | `Client httpClient()` | *(override)* A platform-appropriate HTTP client (see the variant table). |
| `getBrowserLocation` | `String? getBrowserLocation()` | *(override)* The browser location URL, or `null` off the web. |
| `getIsolateName` | `String getIsolateName()` | *(override)* A short name for the current isolate. |
| `toString` | `String toString()` | *(override)* Identifies the active variant. |
