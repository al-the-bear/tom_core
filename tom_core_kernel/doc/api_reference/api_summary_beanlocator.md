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
  - [TomNullInterface](#tomnullinterface)
  - [TomNoInterface](#tomnointerface)
  - [TomBean\<T\>](#tombeant)
- [Global Functions and Constants](#global-functions-and-constants)

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
the best-matching implementation for the active runtime.
`TomBeanLocatorException` is raised for duplicate registrations, unresolved
beans, type mismatches, and ambiguous or missing implementations.

## Class Hierarchy

```
TomException  (kernel)
    └── TomBeanLocatorException

TomComponent

(interfaces)
├── TomNullInterface
└── TomNoInterface

TomBean<T>
```

## Classes

### TomBeanLocatorException

Exception thrown when bean locator operations fail, e.g. bean instantiation and
registration, resolution by name or type, and duplicate bean detection.

- **Extends:** `TomException`

#### Constructors

```dart
TomBeanLocatorException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool? autoLog,
})
```

### TomComponent

Annotation to mark a class as a Tom component / service bean. When applied
alongside `@tomReflector`, the bean locator discovers and instantiates the class
during initialization. Combine with `@TomEnvironment` or `@TomPlatform` for
environment- or platform-specific implementations.

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

### TomNullInterface

Marker interface indicating a null/missing component.

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
```

`fromName` creates a handle that resolves by registered name. `withName`
registers a named bean and returns a handle for it, throwing
`TomBeanLocatorException` if the name already exists. `withType` registers a
bean by type (taking precedence over `@TomComponent` registrations for the same
type), throwing `TomBeanLocatorException` if the type is already registered.

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `installByEnvironment` | `static TomBean<T> installByEnvironment<T>(Map<String, T Function()> factories, {String? environment})` | Selects and installs exactly one implementation of `T` by the active environment name (from `environment` or `TomRuntime.getCurrentEnvironment`); registers the built instance by type. Throws `TomBeanLocatorException` if no factory is registered for the active environment. |
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
| `initializeBeanContext` | `void initializeBeanContext()` | Initializes the bean context by discovering `@TomComponent`-annotated classes via reflection, filtering by environment/platform, instantiating and registering beans, and validating all `TomBean` references. |
