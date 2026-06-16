# tom_core_flutter

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are proprietary and internal (`publish_to: none`).

Flutter integration layer for the Tom Framework — re-exports
[`tom_core_kernel`](../tom_core_kernel/README.md) and adds Flutter widgets,
form primitives, and client utilities.

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
- **Form primitives** — the foundational field/form objects (`TomFieldOld`,
  `TomFormOld`) that bind observable values to validation.
- **UI-bound properties** — typed `TomProperty<T>` accessors over the kernel
  resource tree.
- **Client platform detection** — the Flutter/web/IO variant selector for the
  kernel's `TomPlatformUtils`.
- **Client security** — the `TomClient2FAAdaptor` annotation for two-factor
  adaptors.

### Relationship to `tom_flutter_ui`

`tom_core_flutter` is the **low-level binding** layer; it is *not* the
application widget toolkit. The rich, ACL-aware widget set — the modern forms
framework, the advanced-container-layout engine, theming, and `resource_auth`
— lives in [`tom_flutter_ui`](../tom_flutter_ui/README.md). The form types here
carry the `Old` suffix (`TomFieldOld`, `TomFormOld`) precisely because they are
the original primitives; new UI work should reach for `tom_flutter_ui`'s forms
instead.

The two demo/test harnesses make the split concrete:
[`tom_flutter_form_test`](../tom_flutter_form_test) and
[`tom_flutter_ui_test`](../tom_flutter_ui_test) target
**`tom_flutter_ui` + `tom_core_kernel`** directly — they do **not** depend on
`tom_core_flutter`. Reach for `tom_core_flutter` when you want the kernel on
Flutter with the minimal binding helpers; reach for `tom_flutter_ui` when you
want the full UI/forms/ACL toolkit.

## Installation

This package is internal to the Tom workspace and consumed by path (it is
`publish_to: none`), so there is no `dart pub add` line:

```yaml
dependencies:
  tom_core_flutter:
    path: ../tom_core_flutter
```

Then import the single barrel — it re-exports `tom_core_kernel` and
`tom_reflection`, so you rarely import those directly:

```dart
import 'package:tom_core_flutter/tom_core_flutter.dart';
```

**SDK:** Dart `^3.10.4` with the Flutter SDK. Modules that use reflection
(forms, security adaptors) require `dart run build_runner build` to generate
`*.reflection.dart`.

## Features

### Observing widgets (`observing`)

| Type | What it is |
| ---- | ---------- |
| `TomObservingWidget<T extends TomObservable>` | A `StatefulWidget` that rebuilds its `child` builder whenever the bound `subState` notifies |
| `TomObservingWidgetState<T>` | The `TomObserver` state behind the widget (registers/rebuilds on notify) |
| `ValueListenableObserver<T extends TomObservable>` | Bridges a kernel `TomObservable` to a Flutter `Listenable`/listener |

### Forms (`forms`)

| Type | What it is |
| ---- | ---------- |
| `TomFieldOld<T>` | Observable form field (`TomObject<T>`) with validation passes and `save()` |
| `TomEmailField<T>` / `TomPasswordField<T>` | Specialised field primitives with built-in validators |
| `TomFormOld` | A `TomMap<String, TomFieldOld>` aggregating fields into a validated form |

### Resources (`resources`)

| Type | What it is |
| ---- | ---------- |
| `TomProperty<T>` | Typed accessor over the kernel resource/config tree, with `.withDefault` fallback |
| `TomStringProperty` / `TomIntProperty` / `TomDoubleProperty` / `TomBoolProperty` | Concrete typed property variants |

### Runtime (`runtime`)

| Type | What it is |
| ---- | ---------- |
| `clientPlatformUtils` | Returns the platform-appropriate kernel `TomPlatformUtils` (Flutter/web/IO/neutral), selected at compile time |

### Security (`security`)

| Type | What it is |
| ---- | ---------- |
| `TomClient2FAAdaptor` | Annotation marking a class as a client-side two-factor (2FA) adaptor for a given type |

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
  child: (state) => Text('Count: ${~state}'), // ~ reads the value
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
| [`example/forms/`](example/forms/forms_example.dart) | Building `TomFieldOld`/`TomFormOld`, the two validation passes, reading values via `save()` |
| [`example/resources/`](example/resources/resources_example.dart) | Resolving typed config via `TomProperty` subclasses and `.withDefault` |
| [`example/runtime/`](example/runtime/runtime_example.dart) | Obtaining the platform-appropriate `TomPlatformUtils` and querying its predicates |
| [`example/security/`](example/security/security_example.dart) | Applying the `TomClient2FAAdaptor` marker annotation and reading back its `type` |
| [`example/little_things/`](example/little_things/little_things_example.dart) | The two client exception types and the type-based discrimination pattern |

> **Cross-package sample.** The `tom_core_samples/core_client_sample` project
> (forthcoming) builds a login-gated todo client on this package — CRUD forms
> whose fields render hidden / read-only / disabled / editable straight from the
> server's authorization decisions. See the
> [samples map](../tom_core_samples/README.md) for the full learning path.

## Usage

### Observing kernel state in a widget

```dart
final name = TomString('Ada');

TomObservingWidget<TomString>(
  subState: name,
  child: (state) => Text(~state), // rebuilds on every notify
);

name | 'Grace'; // widget now shows "Grace"
```

### Binding form fields

```dart
final email = TomEmailField<String>();
final password = TomPasswordField<String>();
final form = TomFormOld()
  ..['email'] = email
  ..['password'] = password;

email | 'ada@example.com';
final isValid = form.validate(); // runs each field's validators
final values = form.save();      // collects the field values
```

### Reading typed configuration

```dart
final timeout = TomIntProperty('http.timeoutSeconds');
final seconds = timeout.withDefault(30); // falls back when unset
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
   ┌─────────┼──────────┬───────────┬───────────┐
 observing  forms   resources   runtime     security
 (rebuild) (TomFieldOld) (TomProperty) (platform) (2FA marker)
             │
       tom_core_kernel  (TomObservable, TomObject, TomPlatformUtils, …)
```

| Type | Responsibility |
| ---- | -------------- |
| `TomObservingWidget` | Rebuilds a subtree when its observable notifies |
| `ValueListenableObserver` | Adapts a `TomObservable` to a Flutter listener |
| `TomFieldOld` / `TomFormOld` | Foundational observable form field / form |
| `TomProperty<T>` | Typed accessor over the kernel resource tree |
| `clientPlatformUtils` | Selects the concrete `TomPlatformUtils` for Flutter |
| `TomClient2FAAdaptor` | Marks a client two-factor adaptor class |
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
  (`doc/observing.md`, `doc/forms.md`, `doc/resources.md`, `doc/runtime.md`,
  `doc/security.md`, `doc/little_things.md`).
- [`tom_core_kernel`](../tom_core_kernel/README.md) — the platform-neutral
  building blocks re-exported here.
- [`tom_flutter_ui`](../tom_flutter_ui/README.md) — the full UI/forms/ACL
  toolkit the demo apps target.

## Status

- **Version:** 1.1.0
- **Tests:** 47 test cases across 6 module suites (run with `flutter test`).
- **License:** proprietary — see [LICENSE](LICENSE).
