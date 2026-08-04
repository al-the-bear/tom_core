# beanlocator

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

A minimal dependency-injection / service-locator for the kernel. Beans are
registered once (by name or by type) and resolved lazily anywhere in the app
through a typed handle, so collaborators never construct their own dependencies.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomBean<T>` | Typed handle to a registered bean; `withName` / `withType` register, `fromName` resolves, `get()` returns the instance. |
| `TomComponent` | Base marker for objects participating in the locator. |
| `TomNoInterface` | Sentinel interface for beans registered without a declared interface type. |
| `TomBeanLocatorException` | Thrown on duplicate registration or failed resolution. |

## Quick start

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

class AppConfig {
  final String env;
  AppConfig(this.env);
}

void main() {
  // Register a bean under a name.
  TomBean.withName('config', AppConfig('prod'));

  // Resolve it lazily, anywhere in the app.
  final config = TomBean<AppConfig>.fromName('config').get();
  print(config.env); // prod
}
```

---

Part of [`tom_core_kernel`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
