# Tom Core Flutter

`tom_core_flutter` is the Flutter integration layer of the Tom Framework. It
re-exports the whole platform-neutral [`tom_core_kernel`](../tom_core_kernel)
(dependency injection, observable state, security, resources, runtime
utilities) and adds the Flutter-specific pieces on top: widgets that bind to
observable kernel state, form primitives, typed UI properties, client-side
platform detection, and client authentication helpers.

Because it surfaces the kernel through its own barrel, a Flutter app only needs
to depend on `tom_core_flutter` — importing it gives you both the kernel API and
the Flutter extensions.

## Getting started

This package is internal to the Tom workspace and is consumed by path:

```yaml
dependencies:
  tom_core_flutter:
    path: ../tom_core_flutter
```

Import the single barrel — it re-exports `tom_core_kernel` and
`tom_reflection`, so you rarely need to import those directly:

```dart
import 'package:tom_core_flutter/tom_core_flutter.dart';
```

## Usage

Rebuild a widget automatically whenever an observable kernel value changes:

```dart
final counter = TomInt(0);

TomObservingWidget<TomInt>(
  subState: counter,
  child: (state) => Text('Count: ${~state}'),
);

counter | 5; // the widget rebuilds with "Count: 5"
```

## Modules

| Module | Summary |
| ------ | ------- |
| Observing | `TomObservingWidget` and `ValueListenableObserver` — rebuild Flutter widgets in response to `TomObservable` kernel state |
| Forms | Form field and form-state primitives (`TomFieldOld`, `TomEmailField`, `TomPasswordField`, `TomFormOld`) built on observable objects |
| Resources | `TomProperty<T>` and typed variants (`TomStringProperty`, `TomIntProperty`, `TomDoubleProperty`, `TomBoolProperty`) for UI-bound configuration values |
| Runtime | `clientPlatformUtils` — conditional platform detection (web / native IO / neutral) returning a kernel `TomPlatformUtils` |
| Security | `TomClient2FAAdaptor` — client-side authentication and two-factor helpers |
| Little Things | `TomClientException` / `TomClientUIException` — client-side exception types extending the kernel `TomException` |

### Placeholder modules

The following module folder is reserved for a planned client capability and
currently contains only a `readme.md` placeholder (no implementation):
`qrcode`.

## Additional information

- **Kernel API:** all of `tom_core_kernel` is re-exported here; see its
  [README](../tom_core_kernel/README.md) and module docs for the underlying
  building blocks.
- **Tests:** run with `flutter test` from the package root.
- **License:** proprietary — see [LICENSE](LICENSE).
