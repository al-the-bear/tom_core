# Tom Core Kernel

`tom_core_kernel` is the foundation library of the Tom Framework. It bundles the
platform-neutral building blocks the rest of the framework (server, Flutter, and
DartScript layers) is composed from: dependency injection, observable state,
security and authorization, resource resolution, logging, and a set of runtime
utilities.

The package is reflection-aware (via `tom_reflection`) and has no UI or
server-runtime dependencies, so it can be consumed from any Dart target.

## Getting started

Add the dependency (this package is internal — consumed by path within the Tom
workspace):

```yaml
dependencies:
  tom_core_kernel: any
```

Import the single barrel and use any module:

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';
```

## Usage

Observable state with automatic observer propagation:

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

final count = TomInt(0);
count >> (obs) => print('changed to ${~count}');
count | 5; // prints: changed to 5
```

Namespacing lookups with a zone-propagated scope:

```dart
TomScope.withScope('checkout', () {
  TomScope.withScope('orderForm', () {
    print(TomScope.current.getScopePath()); // checkout.orderForm
  });
});
```

Each module ships runnable examples under
[`example/`](example/) (every module folder has a `00_run_all_examples.dart`
runner) and a guide under [`doc/`](doc/).

## Modules

| Module | Summary | Docs |
| ------ | ------- | ---- |
| Bean Locator | Reflection-based dependency-injection container for service beans | [doc](doc/beanlocator/beanlocator.md) |
| Context | Ambient execution-context management | [doc](doc/context/context.md) |
| HTTP Connection | HTTP connection helpers | [doc](doc/http_connection/http_connection.md) |
| Isolate Pooling | Worker-pool execution across isolates | [doc](doc/isolate_pooling/isolate_pooling.md) |
| JSON | JSON serialization and tree utilities | [doc](doc/json/json.md) |
| Little Things | Small zone/utility helpers (e.g. `getFromCurrentZone`) | [doc](doc/little_things/little_things.md) |
| Logging | Structured logging, including isolate and remote logging | [doc](doc/logging/logging.md) |
| Observable | Observable objects: `TomObject`, `TomClass`, `TomList`, `TomMap` | [doc](doc/observable/observable.md) |
| Reflection | Reflection support and helpers | [doc](doc/reflection/reflection.md) |
| Resources | Text and configuration resource providers | [doc](doc/resources/resources.md) |
| Scope IDs | Hierarchical, zone-propagated scope identifiers | [doc](doc/scope_ids/scope_ids.md) |
| Security | Authentication, authorization, access control, and the four-state UI authorization model | [doc](doc/security/security.md) |
| Settings | Settings management | [doc](doc/settings/settings.md) |
| Shutdown Cleanup | Ordered shutdown/cleanup hooks | [doc](doc/shutdown_cleanup/shutdown_cleanup.md) |
| Timezoned | Timezone-aware date/time support | [doc](doc/timezoned/timezoned.md) |

## Additional information

- **Examples:** `example/{module}/00_run_all_examples.dart` — run with
  `dart run example/{module}/00_run_all_examples.dart`. Modules that use
  reflection require `dart run build_runner build` first.
- **Tests:** run with `testkit :test` (or `dart test`) from the package root.
- **License:** proprietary — see [LICENSE](LICENSE).
