# beanlocator

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

A minimal dependency-injection / service-locator for the kernel. A bean is
either discovered from its `@TomComponent` annotation at start-up or registered
by hand; either way it is resolved lazily through a typed handle, so a
collaborator declares the dependency it needs instead of constructing it.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomBean<T>` | Typed handle to a bean, resolving lazily on `get()` (or on `()`). The factories also register: `withName` / `withType` bind a key, `overrideWithName` / `overrideWithType` replace one, `fromName` binds a handle to a name that need not exist yet. |
| `TomComponent` | The discovery annotation — not a base class, and nothing to implement. It carries the interface `Type` the annotated class registers under: `@TomComponent(UserService)` on an implementation, or `@tomComponent` on a class that registers under its own concrete type. |
| `TomNoInterface` | The `Type` `@tomComponent` carries, meaning "register me by my own type". |
| `TomBeanLocatorException` | Thrown on duplicate registration, failed resolution, an interface with no matching or several equally matching implementations, and a runtime that is not configured yet. |

`initializeBeanContext()` is the discovery pass: it scans the reflected classes
for `@TomComponent`, picks exactly one implementation per interface — narrowing
by the `@TomEnvironment` / `@TomPlatform` selectors the candidates carry, which
match on **name** — instantiates it through its unnamed no-argument constructor,
and finally resolves every handle declared so far, so a missing binding fails at
start-up rather than at first use. Note what it does *not* do: nothing is
injected into a bean. A dependency is a `TomBean<T>` field the bean resolves
itself on first access, which is also why a bean must not resolve one in its
constructor.

## Quick start

### Discovered from annotations

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

abstract class GreetingService {
  String greet(String name);
}

// No interface named, so `@tomComponent` registers this under its own type.
// Discovery builds it with the unnamed no-argument constructor.
@tomReflector
@tomComponent
class AppConfig {
  String env = 'prod';
}

@tomReflector
@TomComponent(GreetingService)
class EnglishGreetingService implements GreetingService {
  // A dependency is a handle that resolves itself — not a constructor
  // parameter the container fills in.
  final TomBean<AppConfig> config = TomBean();

  @override
  String greet(String name) => 'Hello $name, from ${config().env}';
}

void main() {
  initializeReflection(); // from the generated *.reflection.dart

  // Selection compares every candidate against the active deployment, so the
  // runtime has to be configured before discovery runs. An application usually
  // detects the platform instead — `TomPlatformUtils.setCurrentPlatform(…)`
  // followed by `TomRuntime.initializePlatform()`; naming it keeps this
  // snippet self-contained.
  TomRuntime.addEnvironment(const TomEnvironment('prod'));
  TomRuntime.setCurrentEnvironment('prod');
  TomRuntime.setCurrentPlatform(platformLinux);

  initializeBeanContext();

  print(TomBean<GreetingService>().get().greet('Ada'));
}
```

### Registered by hand

```dart
void main() {
  // Register a bean under a name …
  TomBean.withName('config', AppConfig()..env = 'staging');
  print(TomBean<AppConfig>.fromName('config').get().env); // staging

  // … or under a type. Discovery then leaves that key alone — a binding is an
  // answer, not a candidate — which is how a test substitutes a stub.
  TomBean.withType(GreetingService, StubGreetingService());
}
```

The four-tier selection between candidate implementations, named beans, startup
validation and the full error-key table are covered in
[`doc/beanlocator/beanlocator.md`](../../../../doc/beanlocator/beanlocator.md).

---

Part of [`tom_core_kernel`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
