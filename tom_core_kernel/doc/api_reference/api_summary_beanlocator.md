# Tom Core Kernel API Reference: Bean Locator Module

A lightweight dependency-injection / service-locator container that uses Tom
reflection to discover, instantiate, and wire service beans, with support for
environment- and platform-specific implementations.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomBeanLocatorException](#tombeanlocatorexception)
  - [TomComponent](#tomcomponent)
  - [TomNoInterface](#tomnointerface)
  - [TomBean\<T\>](#tombeant)
- [Global Functions and Constants](#global-functions-and-constants)
  - [Constants](#constants)
  - [Functions](#functions)

## Overview

Source: `lib/src/tombase/beanlocator/bean_locator.dart`.

The Bean Locator provides a lightweight dependency-injection container built on
Tom reflection. Classes annotated with `@TomComponent` (alongside
`@tomReflector`) are discovered and instantiated when `initializeBeanContext`
runs; a bean is registered either by its concrete type (`TomNoInterface`) or by
the interface `Type` given to `@TomComponent`. `TomBean<T>` is a type-safe,
lazily resolved handle onto that registry: it resolves a bean by type
assignability, by registered name (`TomBean.fromName`), or from an explicit
registration (`TomBean.withName` / `TomBean.withType` / `installByEnvironment`).
Environment (`@TomEnvironment`) and platform (`@TomPlatform`) annotations pick
the best-matching implementation for the active runtime; a selector matches on
the environment or platform **name**, so the value handed to `TomRuntime` may be
built at runtime from configuration rather than written as a `const`.
`TomBeanLocatorException` is raised for duplicate registrations, unresolved
beans, type mismatches, ambiguous or missing implementations, and an
unconfigured runtime. It is the module's *only* exception type: a failure
originating in `TomRuntime` is translated at the boundary, so `on
TomBeanLocatorException` is a sufficient handler.

## Class Hierarchy

```
TomException  (kernel)
    └── TomBeanLocatorException

TomComponent

(interfaces)
└── TomNoInterface

TomBean<T>
```

## Classes

### TomBeanLocatorException

Exception thrown when bean locator operations fail, e.g. bean instantiation and
registration, resolution by name or type, duplicate bean detection, and an
operation that needed the active environment before the runtime was configured
(`beanlocator.environment.runtime_environment_not_initialized`, whose
`operation` / `subject` parameters name what was being wired).

- **Extends:** `TomException`

#### Constructors

```dart
TomBeanLocatorException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool autoLog = false,
})
```

### TomComponent

Annotation to mark a class as a Tom component / service bean. When applied
alongside `@tomReflector`, the bean locator discovers and instantiates the class
during initialization. Combine with `@TomEnvironment` or `@TomPlatform` for
environment- or platform-specific implementations; both are matched by name, so
`TomEnvironment("test")` and `TomEnvironment("test", isTest: true)` select
identically and `"none"` is reserved for the unconstrained sentinels.

#### Constructors

```dart
const TomComponent(Type type)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `type` | `Type` | The interface type this component is registered under (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `getType` | `Type getType()` | Returns the interface type for this component. |
| `toString` | `String toString()` | *(override)* Renders as `TomComponent of <type>`. |

### TomNoInterface

Marker interface indicating a component without a specific interface. Use it
when a bean should be registered by its concrete type rather than an interface.

### TomBean\<T\>

A type-safe handle for accessing dependency-injected beans, resolving them
lazily by type or by name.

- **Type Parameters:** `<T>`

#### Constructors

```dart
TomBean()
```

Creates an unresolved bean handle for type `T`; the bean is resolved lazily when
`get` is called.

#### Factory Constructors

```dart
factory TomBean.fromName(String name)

factory TomBean.withName(String name, Object bean)

factory TomBean.withType(Type t, Object bean)

factory TomBean.overrideWithName(String name, Object bean)

factory TomBean.overrideWithType(Type t, Object bean)
```

`fromName` creates a handle that resolves by registered name; the name need not
be registered yet, so a handle may be held as a field and the bean registered
later in startup. `withName`
registers a named bean and returns a handle for it, throwing
`TomBeanLocatorException` if the name already exists. `withType` registers a
bean by type, throwing `TomBeanLocatorException` if the type is already
registered — including a type discovery has bound; a registration made before
`initializeBeanContext` does take precedence, since discovery leaves an occupied
key alone.

`overrideWithName` and `overrideWithType` replace whatever is registered under
the key instead of refusing it, for substituting an implementation in a test.
Note that a handle which has already resolved keeps its instance, that
`initializeBeanContext` discards overrides, and that the replacement must be
assignable to the type consumers request.

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `installByEnvironment` | `static TomBean<T> installByEnvironment<T>(Map<String, T Function()> factories, {String? environment})` | Selects and installs exactly one implementation of `T` by the active environment name (from `environment` or `TomRuntime.getCurrentEnvironment`); registers the built instance by type. Throws `TomBeanLocatorException` if no factory is registered for the active environment, or if `environment` is omitted and no runtime environment is configured. |
| `getBeanByType` | `static Object? getBeanByType(Type type)` | Returns the bean registered for `type`, or `null` if not found. |
| `getBeanByName` | `static Object? getBeanByName(String name)` | Returns the bean registered with `name`, or `null` if not found. |
| `resetBeanContext` | `static void resetBeanContext()` | Clears all registered beans, drops pending unresolved handles, and marks the context uninitialized so a later `initializeBeanContext` starts clean. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `getType` | `Type getType()` | Returns the type parameter `T`. |
| `get` | `T get()` | Resolves and returns the bean: returns the cached instance if present, otherwise resolves by name (if named) or by type assignability. Throws `TomBeanLocatorException` if resolution fails. |
| `call` | `T call()` | Callable shortcut for `get`. |
| `getBeanType` | `Type getBeanType()` | Returns the bean type `T`. |

## Global Functions and Constants

### Constants

| Constant | Type | Description |
| -------- | ---- | ----------- |
| `tomComponent` | `TomComponent` | Default component annotation for beans without a specific interface; equivalent to `@TomComponent(TomNoInterface)`. |

### Functions

| Function | Signature | Description |
| -------- | --------- | ----------- |
| `initializeBeanContext` | `void initializeBeanContext()` | Initializes the bean context by discovering `@TomComponent`-annotated classes via reflection, filtering by environment/platform, instantiating and registering beans, and validating the pending `TomBean` references. Requires a configured runtime whenever a discovered class carries a selector or an interface has candidates to choose between. |
| `validateBeanReferences` | `void validateBeanReferences()` | Resolves every pending `TomBean` handle so a missing binding is reported now rather than at the first call that needed it; the last step of `initializeBeanContext`, and public because that is not the only moment worth checking. A handle constructed after the last pass is checked by the next one, and an application that initializes once has none — re-running `initializeBeanContext` is not the remedy, since it rebuilds the registry and drops every imperative registration made since. A handle awaiting a *named* registration is skipped and stays pending, so the deferral ends when the name arrives; a handle it vouched for is dropped, so a second call sees only what appeared since the first. |

Validation resolves every handle constructed since the previous pass — including
one constructed *between* two passes, which the next pass validates — so a typed
handle nothing bound fails at boot rather than at first use. A handle awaiting a
*named* registration is skipped: discovery registers only under `Type` keys, so
it can never supply a name, and demanding one would make the supported
"register later" pattern a startup failure. A named handle whose name *is*
registered is validated normally, so a type mismatch still fails at boot.
