# tom_core_flutter

Published on pub.dev as [`tom_core_flutter` 1.2.1](https://pub.dev/packages/tom_core_flutter).

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and published on pub.dev.

> **⚠️ Work in progress — unstable API.** The Tom Core packages are under active
> development and not yet stable. Their version numbers carry no promise about
> API maturity: they are publishing counters, not semver. The patch number is
> bumped on every change — **including breaking changes** — so a patch bump may
> break you. Expect the public surface to shift without notice. Not recommended
> for production use yet.

Flutter integration layer for the Tom Framework — re-exports
[`tom_core_kernel`](../tom_core_kernel/README.md) and adds Flutter widgets and
client utilities.

## Overview

`tom_core_flutter` is the thin **binding layer** that brings the platform-neutral
[`tom_core_kernel`](../tom_core_kernel/README.md) onto a Flutter target. It
re-exports the entire kernel barrel (observable state, dependency injection,
security, resources, runtime utilities) plus
[`tom_reflection`](../../reflection/tom_reflection/README.md), so a Flutter app
that depends on `tom_core_flutter` gets both the kernel API and the
Flutter-specific extensions through a single import.

What it adds on top of the kernel is deliberately small:

- **Observing widgets** that rebuild when a kernel `TomObservable` notifies.
- **UI-bound properties** — typed `TomProperty<T>` accessors over the kernel
  resource tree.
- **Client configuration** — a machine-scoped settings holder that resolves
  from the shipped config resources, persists this install's overrides, and is
  observable per field and as a whole.
- **Preferences** — machine-local user preferences behind one
  platform-independent API, with the storage backend chosen by DI rather than by
  an `if (kIsWeb)` at the call site, plus the typed client for the account-level
  preferences the server holds.
- **Client platform detection** — the Flutter/web/IO variant selector for
  `TomPlatformUtils`.
- **Client security** — the framework-owned second-factor flow: a
  ready-made enrol-and-challenge panel over a seam onto the application's own
  auth client, pluggable per-mechanism rendering resolved through a registry,
  and the shipped TOTP mechanism. Beside it, the code-scanner contract
  (`TomCodeScanner`): the framework declares how a screen reads QR codes and
  barcodes, and the application implements it over the camera plugin it
  chooses.

### Relationship to `tom_flutter_ui`

`tom_core_flutter` is the **low-level binding** layer; it is *not* the
application widget toolkit. The rich, ACL-aware widget set — the declarative
forms framework, the advanced-container-layout engine, theming, and
`resource_auth` — lives in
[`tom_flutter_ui`](../tom_flutter_ui/README.md). Any UI or forms work should
reach for `tom_flutter_ui`; `tom_core_flutter` only carries the kernel binding
helpers.

The two demo/test harnesses make the split concrete:
[`tom_flutter_form_test`](../tom_core_samples/tom_flutter_form_test) and
[`tom_flutter_ui_test`](../tom_core_samples/tom_flutter_ui_test) target
**`tom_flutter_ui` + `tom_core_kernel`** directly — they do **not** depend on
`tom_core_flutter`. Reach for `tom_core_flutter` when you want the kernel on
Flutter with the minimal binding helpers; reach for `tom_flutter_ui` when you
want the full UI/forms/ACL toolkit.

## Installation

Add it from pub.dev:

```yaml
dependencies:
  tom_core_flutter: ^1.2.1
```

Then import the single barrel — it re-exports `tom_core_kernel` and
`tom_reflection`, so you rarely import those directly:

```dart
import 'package:tom_core_flutter/tom_core_flutter.dart';
```

**SDK:** Dart `^3.10.4` with the Flutter SDK. Modules that use reflection
(security adaptors) require `dart run build_runner build` to generate
`*.reflection.dart`.

## Features

### Observing widgets (`observing`)

| Type | What it is |
| ---- | ---------- |
| `TomObservingWidget<T extends TomObservable>` | A `StatefulWidget` that rebuilds its `child` builder whenever the bound `subState` notifies |
| `TomObservingWidgetState<T>` | The `TomObserver` state behind the widget (registers/rebuilds on notify) |
| `ValueListenableObserver<T extends TomObservable>` | Bridges a kernel `TomObservable` to a Flutter `Listenable`/listener |

### Resources (`resources`)

| Type | What it is |
| ---- | ---------- |
| `TomProperty<T>` | Typed accessor over the kernel resource/config tree, with `.withDefault` fallback |
| `TomStringProperty` / `TomIntProperty` / `TomDoubleProperty` / `TomBoolProperty` | Concrete typed property variants |

### Client configuration (`configuration`)

| Type | What it is |
| ---- | ---------- |
| `TomBaseClientConfiguration` | Base class for a client app's **machine-scoped** settings holder — declare, load, observe, persist |
| `TomSetting<T>` | One observable setting: a `TomObject<T>` plus its dotted key and its baseline |
| `TomClientConfigurationStore` | Two-method interface (`read` / `update`) for where overrides are persisted |
| `TomMemoryClientConfigurationStore` / `TomFileClientConfigurationStore` | Process-lifetime and JSON-file stores |
| `TomClientConfigurationException` | Module failures, with stable dotted keys |

Only the install's **overrides** are persisted, so shipping a new default in an
app update still reaches installs that never touched that key. See
[`doc/configuration.md`](doc/configuration.md).

### Preferences (`preferences`)

| Type | What it is |
| ---- | ---------- |
| `TomDevicePreferences` | The typed API for this **device's** preferences — resolved as a bean, never constructed at the call site |
| `TomStoredDevicePreferences` | The shipped implementation: the typed API over a store, holding the single encode/decode decision |
| `TomDevicePreferenceStore` | Two-method (`read` / `write`) backend interface — the only platform-specific part |
| `TomPlatformDevicePreferenceStore` | The backend for the current target (JSON file / `localStorage` / loud failure), selected at compile time |
| `TomMemoryDevicePreferenceStore` | A store that persists nothing beyond the process |
| `TomDevicePreferenceJson` | The stored JSON document, written once for every persistent backend |
| `TomDevicePreferenceException` | Device-store failures, with stable dotted keys |
| `TomUserPreferencesClient` | The typed client for the **account's** preferences — the same method set, over the server's `/preferences/*` routes |
| `TomUserPreferencesClientException` | Client failures, with stable dotted keys |

Two stores, one vocabulary. Preferences that must **not** follow the user — the
last account used *here*, whether biometric unlock is on *this* device — stay on
the device; the ones that should follow the user live server-side and are reached
through `TomUserPreferencesClient`. The keys, the DTO and the codec are the
kernel's and both stores carry the same method set, so a preference can move
between them without a call site changing. The client writes no URIs: every
request is resolved from the kernel's `tomUserPreferencesApi` declaration, so it
and the server are two readings of one contract. See
[`doc/preferences.md`](doc/preferences.md).

### Runtime (`runtime`)

| Type | What it is |
| ---- | ---------- |
| `clientPlatformUtils` | Returns the platform-appropriate `TomPlatformUtils` (Flutter/web/IO/neutral), selected at compile time |

### Security (`security`)

| Type | What it is |
| ---- | ---------- |
| `Tom2FAFlowPanel` | Renders whichever stop of a second-factor login the controller reports — chooser, enrolment or challenge |
| `Tom2FAFlowController` | The seam an application implements over its own auth client: five moves, two pieces of read-only state |
| `Tom2FAClientMechanism` | One mechanism's client-side rendering, paired with its server adaptor by mechanism key alone |
| `Tom2FAClientRegistry` | The process-wide mechanism catalog the flow dispatches through |
| `Tom2FAEnrolmentPanelContext` / `Tom2FAChallengePanelContext` | What a mechanism's two panels are given to render themselves |
| `TomTotp2FAClientMechanism` | The shipped authenticator-app mechanism, registered under `'totp'` |
| `TomWebAuthn2FAClientMechanism` | The shipped passkey mechanism, registered under `'webauthn'` where a platform authenticator exists |
| `TomWebAuthnPlatform` | The seam to whatever makes passkeys on this target — the browser on the web |
| `Tom2FATexts` | Every resource key the second-factor UI resolves, and the helpers that resolve them |
| `TomQrCodeView` | A QR code painted from the pure-Dart `qr` encoder, themed like any other widget |
| `TomCodeScanner` | The contract for reading codes with the device camera; the application implements it over its own camera plugin |
| `TomFakeCodeScanner` | The scanner a test drives, delivering the codes and failures the test tells it to |
| `TomScannedCode` / `TomCodeFormat` / `TomCodeScannerAvailability` / `TomCodeScannerException` | A decoded code, the symbologies a scan asks for, whether scanning can work here, and why a scan could not start |

### Little things (`little_things`)

| Type | What it is |
| ---- | ---------- |
| `TomClientException` | Client-side exception extending the kernel `TomException` |
| `TomClientUIException` | UI-surfaced client exception (extends `TomClientException`) |

## Quick start

Rebuild a widget automatically whenever an observable kernel value changes:

```dart
import 'package:tom_core_flutter/tom_core_flutter.dart';

final counter = TomInt(0);

final widget = TomObservingWidget<TomInt>(
  subState: counter,
  builder: (state, _) => Text('Count: ${~state}'), // ~ reads the value
);

counter | 5; // | sets the value → the widget rebuilds with "Count: 5"
```

## Example projects

Each module ships a self-contained example under [`example/`](example/). Because
the barrel pulls in `flutter/material` (and thus `dart:ui`), run them under the
Flutter toolchain (`flutter test` / a Flutter entry point).

| Example | Demonstrates |
| ------- | ------------ |
| [`example/observing/`](example/observing/observing_example.dart) | `ValueListenableObserver` bridging a `TomObservable` to a Flutter listener |
| [`example/resources/`](example/resources/resources_example.dart) | Resolving typed config via `TomProperty` subclasses and `.withDefault`, and both construction-time failures — an unconfigured obligatory key and a value of the wrong type |
| [`example/configuration/`](example/configuration/configuration_example.dart) | Declaring a client settings holder, loading overrides, observing, and persisting only what changed |
| [`example/preferences/`](example/preferences/preferences_example.dart) | Registering a device store once, typed reads/writes, persistence across a restart, reading and writing the account store over a real socket, and the device-over-server precedence |
| [`example/runtime/`](example/runtime/runtime_example.dart) | Obtaining the platform-appropriate `TomPlatformUtils`, querying its predicates beside the Flutter target that decides them, and taking an HTTP client from it |
| [`example/security/`](example/security/security_example.dart) | Walking a `Tom2FAFlowController` through all three stops of a second-factor login — chooser, enrolment and challenge — plus the registry rule that decides what the chooser may list, and resource resolution with its missing-key behaviour |
| [`example/security/`](example/security/code_scanner_example.dart) | Installing and resolving a `TomCodeScanner`, asking its availability, taking the first code of a kind with `scanOnce`, a timeout, and a scan that cannot start — all on the `TomFakeCodeScanner` test double |
| [`example/little_things/`](example/little_things/little_things_example.dart) | The two client exception types and the type-based discrimination pattern |

> **Cross-package sample.** The
> [`tom_core_samples/core_client_sample`](../tom_core_samples/core_client_sample/README.md)
> project builds a login-gated todo client on this package — CRUD forms whose
> fields render hidden / read-only / disabled / editable straight from the
> role's four-state authorization matrix. See the
> [samples map](../tom_core_samples/README.md) for the full learning path.

## Usage

### Observing kernel state in a widget

```dart
final name = TomString('Ada');

TomObservingWidget<TomString>(
  subState: name,
  builder: (state, _) => Text(~state), // rebuilds on every notify
);

name | 'Grace'; // widget now shows "Grace"
```

### Reading typed configuration

```dart
final timeout = TomIntProperty.withDefault('http.timeoutSeconds', 30);
final seconds = ~timeout; // 30 when the key is unset
```

### Holding this install's settings

```dart
class AppConfiguration extends TomBaseClientConfiguration {
  AppConfiguration({super.store});

  late final TomSetting<bool> darkMode;

  @override
  void declareSettings() {
    darkMode = boolSetting('client.ui.darkMode', false);
  }
}

final config = AppConfiguration(store: TomFileClientConfigurationStore(path));
await config.load();     // adopt this install's persisted overrides
config.darkMode | true;  // observers fire, per field and holder-wide
await config.save();     // persist the overrides — and only those
```

### Storing a preference on this device, and on the account

```dart
// The one line in an application that knows where machine-local state lives.
TomBean.withType<TomDevicePreferences>(
  TomStoredDevicePreferences(TomPlatformDevicePreferenceStore(location)),
);

final preferences = TomDevicePreferences.resolve()!;
await preferences.set('device.biometricUnlock', true);

// The account store: the same method set, no URI written by the caller.
final account = TomUserPreferencesClient(baseUri: Uri.parse(serverRoot));
await account.set(TomUserPreferenceKeys.theme, 'dark');

// Device value wins while it exists; the account value is the cross-device
// default, consulted only for a key this device has never written. The account
// side stays a callback so a device-only app need not carry an HTTP client.
final theme = await preferences.getPreferred<String>(
  TomUserPreferenceKeys.theme,
  () => account.get<String>(TomUserPreferenceKeys.theme),
);
```

### Selecting the client platform utils

```dart
TomPlatformUtils.setCurrentPlatform(clientPlatformUtils);
// concrete variant (Flutter IO / web / neutral) chosen at compile time
```

## Architecture

```
        Flutter app
             │
   import 'package:tom_core_flutter/tom_core_flutter.dart'
             │  (re-exports the kernel + tom_reflection)
   ┌─────────┼───────────┬───────────┬───────────────┬──────────────┐
 observing  resources   runtime     security   configuration   preferences
 (rebuild) (TomProperty) (platform) (2FA marker) (install       (device-local
                                                  settings)      values)
             │
       tom_core_kernel  (TomObservable, TomObject,
                         TomUserPreferenceDto / Keys / Codec, …)
             │  (re-exports the whole of tom_basics)
         tom_basics     (TomPlatformUtils, TomFallbackPlatformUtils, …)
```

| Type | Responsibility |
| ---- | -------------- |
| `TomObservingWidget` | Rebuilds a subtree when its observable notifies |
| `ValueListenableObserver` | Adapts a `TomObservable` to a Flutter listener |
| `TomProperty<T>` | Typed accessor over the kernel resource tree |
| `TomBaseClientConfiguration` | Owns the machine-scoped settings of one install |
| `TomSetting<T>` | One observable, persistable setting |
| `TomClientConfigurationStore` | Persists the install's overrides |
| `TomDevicePreferences` | The typed, platform-independent API for this device's preferences |
| `TomDevicePreferenceStore` | Persists the device's preferences (file / `localStorage`) |
| `clientPlatformUtils` | Selects the concrete `TomPlatformUtils` for Flutter |
| `TomClientException` | Base client-side exception type |

## Ecosystem

```
tom_basics · tom_crypto · tom_reflection
                 │
          tom_core_kernel
                 │
        ┌────────┴─────────┐
 tom_core_flutter     tom_flutter_ui
 (kernel-on-Flutter   (rich widgets, forms,
  binding layer)       ACL, theming)
        ← you are here
```

`tom_core_flutter` sits directly on `tom_core_kernel` and re-exports it, so
Flutter apps get the full kernel API through one dependency. The richer widget
toolkit lives in [`tom_flutter_ui`](../tom_flutter_ui/README.md). See the
[repository map](../README.md) for the full picture.

## Further documentation

- Per-module guides under [`doc/`](doc/) — one markdown file per module
  (`doc/observing.md`, `doc/resources.md`, `doc/configuration.md`,
  `doc/preferences.md`, `doc/runtime.md`, `doc/security.md`,
  `doc/little_things.md`).
- Per-module API reference under [`doc/api/`](doc/api/) —
  start at
  [`doc/api/api_summary_index.md`](doc/api/api_summary_index.md)
  for the type index and one `api_summary_{module}.md` per module.
  (`doc/api/` is reserved for generated `dart doc` HTML and is gitignored.)
- [`tom_core_kernel`](../tom_core_kernel/README.md) — the platform-neutral
  building blocks re-exported here.
- [`tom_flutter_ui`](../tom_flutter_ui/README.md) — the full UI/forms/ACL
  toolkit the demo apps target.

## Status

- **Version:** 1.2.1
- **Tests:** a module suite per module, each of which also runs the example
  it documents, plus three guards over what the package says about itself: one
  over the markdown — its links, its anchors, its tables of contents and the
  dependencies each module document claims — one over the command each
  example tells a reader to run, and one over the comments in the test files
  themselves, which may state the contract under test but neither the phase of
  their own authorship nor a numbered section of a document that was never
  committed (all with `flutter test`). Two module suites
  additionally hold their own documents to what the code does: the preferences
  store's list-ownership contract, and — in resources — the recommendation to
  prefer a typed subclass together with its nullable-`T` exception, and the
  wording and number of the failures the module throws.

  No count is given: a count is a claim nothing checks, and every added test
  would be a README edit nobody makes. What the suites *do* is the part worth
  stating, and it does not drift with the count.
- **License:** BSD-3-Clause — see [LICENSE](LICENSE).
