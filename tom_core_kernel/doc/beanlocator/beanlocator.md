# Tom Bean Locator System

The Tom Bean Locator System provides a lightweight dependency injection container that uses Dart reflection to automatically discover, instantiate, and wire service beans. It supports environment-specific and platform-specific bean implementations for flexible configuration.

## Table of Contents

- [Overview](#overview)
  - [How It Works](#how-it-works)
- [Quick Start](#quick-start)
  - [Complete Initialization Sequence](#complete-initialization-sequence)
  - [Basic Bean Registration and Resolution](#basic-bean-registration-and-resolution)
  - [Declaring Bean Dependencies](#declaring-bean-dependencies)
- [Core Components](#core-components)
  - [TomBean](#tombean)
    - [Resolution by Type](#resolution-by-type)
    - [Resolution by Name](#resolution-by-name)
    - [Callable Syntax](#callable-syntax)
  - [TomComponent](#tomcomponent)
- [Bean Registration](#bean-registration)
  - [Concrete Type Beans](#concrete-type-beans)
  - [Interface-Based Beans](#interface-based-beans)
  - [Named Beans](#named-beans)
  - [Optional Typed Beans Registration](#optional-typed-beans-registration)
  - [Substituting an Implementation](#substituting-an-implementation)
- [Environment and Platform Beans](#environment-and-platform-beans)
  - [Environment-Specific Beans](#environment-specific-beans)
  - [Selecting an Implementation by Environment Name](#selecting-an-implementation-by-environment-name)
  - [Platform-Specific Beans](#platform-specific-beans)
  - [Selectors Match by Name](#selectors-match-by-name)
- [Resetting the Bean Context](#resetting-the-bean-context)
- [Implementation Resolution](#implementation-resolution)
- [Startup validation](#startup-validation)
- [Error Handling](#error-handling)
  - [TomBeanLocatorException](#tombeanlocatorexception)
  - [Error Keys](#error-keys)
  - [The runtime must be configured before the bean context](#the-runtime-must-be-configured-before-the-bean-context)
- [Best Practices](#best-practices)
  - [1. Initialize in Correct Sequence](#1-initialize-in-correct-sequence)
  - [2. Prefer Interfaces](#2-prefer-interfaces)
  - [3. Store Bean References](#3-store-bean-references)
  - [4. Use Specific Environments](#4-use-specific-environments)
  - [5. No Bean Resolution in Constructors](#5-no-bean-resolution-in-constructors)
  - [6. For Client/Flutter Apps: Use Environment-Specific main_xxx.dart Files](#6-for-clientflutter-apps-use-environment-specific-main_xxxdart-files)
- [Dependencies](#dependencies)

## Overview

The bean locator system consists of several key components:

1. **`TomBean<T>`**: A generic handle for accessing dependency-injected beans with lazy resolution by type or name.

2. **`TomComponent`**: An annotation to mark classes as beans, optionally specifying the interface they implement.

The bean locator integrates with the [Runtime System](../../../../basics/tom_basics/doc/runtime/runtime.md), which `tom_basics` provides, for environment and platform configuration:

- **`TomEnvironment`**: Configuration for runtime environments (dev, test, prod) with hierarchy support
- **`TomPlatform`**: Configuration for target platforms (iOS, Android, Web, etc.)
- **`TomRuntime`**: Central manager for current environment and platform state

### How It Works

1. Classes are annotated with `@tomReflector` and `@TomComponent`
2. At startup, `initializeBeanContext()` scans annotated classes via reflection
3. Beans are instantiated and registered in the global context
4. Components request beans via `TomBean<T>().get()`
5. The locator resolves the best-matching implementation based on type, environment, and platform

## Quick Start

### Complete Initialization Sequence

The bean context requires the runtime system to be initialized first. Here's the complete sequence:

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

// Define environments
const environmentProd = TomEnvironment('prod');
const environmentDev = TomEnvironment('dev', parent: environmentProd, isDevelopment: true);

void initializeRuntime() {
  TomRuntime.addEnvironment(environmentProd);
  TomRuntime.addEnvironment(environmentDev);
  TomRuntime.setRootEnvironment(environmentProd);
  TomRuntime.setCurrentEnvironment(
    TomPlatformUtils.current.getTomEnvVars()["env"], 
    "prod",
  );
  TomRuntime.getCurrentEnvironment().initialize();
  TomRuntime.initializePlatform();
}

// Application main
void main() {
  // 1. Set environment variable (before anything else)
  //    for standalone/server envVar will contain the actual environment
  //    values, so there should be no need to do this
  TomPlatformUtils.envVars["env"] = "dev"; 
  
  // 2. Set platform utilities using the predefined constants/field
  //    for standalone/server application use serverPlatformUtils which are defined
  //    if you import tom_server.dart
  TomPlatformUtils.setCurrentPlatform(clientPlatformUtils);

  
  // 3. Initialize reflection
  initializeReflection();
  
  // 4. Initialize runtime (sets environment and platform)
  initializeRuntime();
  
  // 5. Initialize bean context (AFTER runtime is ready)
  initializeBeanContext();
  
  // 6. Now beans can be resolved
  final userService = TomBean<UserService>().get();

  // 7. Only now start the application — runApp() in a Flutter app.
  startApplication(userService);
}
```

### Basic Bean Registration and Resolution

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

// 1. Define a service interface
abstract class UserService {
  User getUser(int id);
}

// 2. Implement the service (annotate with reflector and component)
@tomReflector
@TomComponent(UserService)
class UserServiceImpl implements UserService {
  @override
  User getUser(int id) => User(id: id, name: 'User $id');
}

// 3. After initialization (see above), resolve and use the bean
void useService() {
  final userService = TomBean<UserService>().get();
  final user = userService.getUser(42);
  print('Got user: ${user.name}');
}
```

### Declaring Bean Dependencies

Services can declare dependencies on other beans using `TomBean<T>` fields:

```dart
@tomReflector
@TomComponent(OrderService)
class OrderServiceImpl implements OrderService {
  // Dependencies are declared as TomBean fields
  TomBean<UserService> userService = TomBean();
  TomBean<PaymentService> paymentService = TomBean();
  TomBean<InventoryService> inventoryService = TomBean();
  
  // Named bean dependency
  TomBean<DatabaseConnection> database = TomBean.fromName("primaryDb");
  
  @override
  Order createOrder(int userId, List<Item> items) {
    // Dependencies are resolved lazily on first access
    final user = userService().getUser(userId);
    paymentService().charge(user, calculateTotal(items));
    inventoryService().reserve(items);
    return Order(user: user, items: items);
  }
}
```

## Core Components

### TomBean

`TomBean<T>` is the primary interface for accessing beans from the container.

#### Resolution by Type

```dart
// Create a handle (does not resolve immediately)
final TomBean<UserService> userServiceBean = TomBean();

// Resolution happens on first access
final userService = userServiceBean.get();
```

#### Resolution by Name

```dart
// Register a named bean
TomBean.withName('mainConfig', AppConfig(host: 'localhost'));

// Resolve by name
final config = TomBean<AppConfig>.fromName('mainConfig').get();
```

#### Callable Syntax

TomBean supports callable syntax for concise access:

```dart
final TomBean<UserService> userService = TomBean();
final user = userService().getUser(123);  // Equivalent to .get().getUser(123)
```

### TomComponent

The `@TomComponent` annotation marks a class as a bean:

```dart
// Concrete type (registered by its own type)
@tomReflector
@tomComponent  // Uses TomNoInterface
class ConfigService { ... }

// Interface-based (registered by interface type)
@tomReflector
@TomComponent(UserService)
class UserServiceImpl implements UserService { ... }
```

## Bean Registration

### Concrete Type Beans

Beans without an interface are registered by their concrete type:

```dart
@tomReflector
@tomComponent
class LoggingService {
  void log(String message) => print('[LOG] $message');
}

// Resolve by concrete type
final logger = TomBean<LoggingService>().get();
```

### Interface-Based Beans

Beans with interfaces are registered by the interface type:

```dart
abstract class CacheService {
  void put(String key, Object value);
  Object? get(String key);
}

@tomReflector
@TomComponent(CacheService)
class MemoryCacheService implements CacheService {
  final _cache = <String, Object>{};
  @override
  void put(String key, Object value) => _cache[key] = value;
  @override
  Object? get(String key) => _cache[key];
}

// Resolve by interface
final cache = TomBean<CacheService>().get();
```

### Named Beans

Register and resolve beans by name:

```dart
// Register
TomBean.withName('primaryDb', DatabaseConnection(host: 'primary.db'));
TomBean.withName('replicaDb', DatabaseConnection(host: 'replica.db'));

// Resolve
final primaryDb = TomBean<DatabaseConnection>.fromName('primaryDb').get();
final replicaDb = TomBean<DatabaseConnection>.fromName('replicaDb').get();
```

The handle may be created before the bean exists. `fromName` records the name
whether or not anything is registered under it, so a handle held as a field
resolves once the registration lands:

```dart
class ReportJob {
  // Created at construction; nothing is registered under this name yet.
  final TomBean<DatabaseConnection> db = TomBean.fromName('primaryDb');

  // The name resolves here, on first use.
  Object? run() => db().query('select * from reports');
}

// …later in startup:
TomBean.withName('primaryDb', DatabaseConnection(host: 'primary.db'));
```

`initializeBeanContext()` does not force such a handle to resolve — see
[Startup validation](#startup-validation) — so it is safe to run the discovery
pass while named registrations are still outstanding.

### Optional Typed Beans Registration

To resolve to service instances that are not marked with @tomReflector/@tomComponent, you can register beans by type:

```dart
// Register, for example in platform initialization, environment initialization...
TomBean.withType(MyService, MyServiceImplementation());

// ... elsewhere, once that registration has run:

// Resolve
final myService = TomBean<MyService>().get();
```

### Substituting an Implementation

Discovery only binds a key nothing has bound yet, so a registration made *before*
`initializeBeanContext()` takes precedence over the annotated component for the
same type — the pass leaves it alone.

Once the context is initialized, however, that route is closed: `withType` and
`withName` refuse a key that is already bound and throw
`beanlocator.initialization.duplicate_bean_with_type` (respectively
`…duplicate_bean_with_name`). That guard is what stops two startup paths from
silently clobbering each other, so replacing a binding has to say so:

```dart
initializeBeanContext();

// Substitute the collaborator under test.
TomBean.overrideWithType(PaymentGateway, MockPaymentGateway());

final gateway = TomBean<PaymentGateway>().get(); // the mock
```

`TomBean.overrideWithName` does the same for a named registration.

Three things about an override fail silently, so they are worth knowing:

- **A handle that has already resolved keeps its instance.** `get()` caches, so a
  collaborator held as a field since before the override still answers with the
  original. Override before the code under test resolves its dependencies.
- **Re-initializing discards it.** `initializeBeanContext()` empties the registry
  (see [Resetting the Bean Context](#resetting-the-bean-context)), so an override
  belongs *after* the pass in `setUp`, and must be re-applied after every later
  pass.
- **The replacement must be assignable** to the type consumers ask for. If it is
  not, resolution skips it and reports the bean as missing rather than as a type
  mismatch.

## Environment and Platform Beans

The bean locator integrates with `TomEnvironment` and `TomPlatform` from the [Runtime System](../../../../basics/tom_basics/doc/runtime/runtime.md) to select different bean implementations based on the current context.

> **Note**: `TomEnvironment`, `TomPlatform` and `TomRuntime` are declared in `tom_basics`, not here. For their own documentation — the environment hierarchy, platform detection, and the `initializeRuntime` sequence this module expects to have run — see [`tom_basics/doc/runtime/runtime.md`](../../../../basics/tom_basics/doc/runtime/runtime.md).

### Environment-Specific Beans

```dart
@tomReflector
@TomComponent(EmailService)
@TomEnvironment('production')
class SmtpEmailService implements EmailService { ... }

@tomReflector
@TomComponent(EmailService)
@TomEnvironment('development', isDevelopment: true)
class ConsoleEmailService implements EmailService { ... }

@tomReflector
@TomComponent(EmailService)
@TomEnvironment('test', isTest: true)
class MockEmailService implements EmailService { ... }
```

### Selecting an Implementation by Environment Name

Annotations let each *implementation* declare which environment it belongs to.
`TomBean.installByEnvironment` inverts that: the caller supplies the mapping and
the locator runs exactly one factory.

```dart
TomBean.installByEnvironment<EmailService>({
  'production': () => SmtpEmailService(),
  'development': () => ConsoleEmailService(),
  'test': () => MockEmailService(),
});

final email = TomBean<EmailService>().get();
```

The active environment comes from `TomRuntime.getCurrentEnvironment()` unless
you pass `environment:` explicitly. Only the selected factory runs, and its
instance is registered by type, so a later `TomBean<EmailService>()` resolves
it. An environment with no entry in the map throws
`beanlocator.environment.no_factory_for_environment` — a missing mapping is a
wiring bug, not a silent fallback.

Reach for this form when the candidate implementations live in packages that
must not depend on one another, or when the choice is driven by a launch flag
rather than by a property of the implementation itself.

### Platform-Specific Beans

```dart
@tomReflector
@TomComponent(StorageService)
@platformIos
class IosStorageService implements StorageService { ... }

@tomReflector
@TomComponent(StorageService)
@platformAndroid
class AndroidStorageService implements StorageService { ... }

@tomReflector
@TomComponent(StorageService)
@platformWeb
class WebStorageService implements StorageService { ... }
```

### Selectors Match by Name

A selector matches the active deployment when the **names** agree. Which
`TomEnvironment` or `TomPlatform` instance carries the name does not matter, so
the environment may be built wherever it is most convenient — including from
configuration, at runtime:

```dart
// Read the environment name at start-up; no `const` in sight.
final name = Platform.environment['APP_ENV'] ?? 'development';
TomRuntime.addEnvironment(TomEnvironment(name));
TomRuntime.setCurrentEnvironment(name);

initializeBeanContext();   // @TomEnvironment('production') matches when name is 'production'
```

This follows from how `TomRuntime` identifies an environment in the first place:
`setCurrentEnvironment` takes a *name*, and registering a second environment
under a name already present is a duplicate registration rather than a second
environment. The name is the identity, and selection agrees with that.

Two consequences:

- Two environments that share a name are the same environment as far as
  selection is concerned, whatever else differs between them — `isTest`,
  `isDevelopment` and `parent` describe an environment but do not distinguish
  one. Give distinct environments distinct names.
- `'none'` is reserved: it is the name of the `noTomEnvironment` and
  `noTomPlatform` sentinels, so a component annotated `@TomEnvironment('none')`
  reads as carrying no environment constraint at all.

## Resetting the Bean Context

The bean context is process-global static state, so a registration made by one
unit of work is still visible to the next. `TomBean.resetBeanContext()` empties
it, drops every pending unresolved handle, and marks the context uninitialized
so a subsequent `initializeBeanContext` starts clean:

```dart
setUp(() {
  TomBean.resetBeanContext();
  initializeBeanContext();
});
```

This is what isolates tests from each other. Application code normally
initializes once at start-up and never resets.

## Implementation Resolution

When multiple implementations exist for an interface, the locator selects based on:

1. **Exact Match**: Both environment AND platform match current runtime
2. **Platform Match**: Platform matches, no environment constraint
3. **Environment Match**: Environment matches, no platform constraint
4. **Default**: No environment or platform constraints

```dart
// Default implementation (no constraints)
@tomReflector
@TomComponent(PaymentService)
class DefaultPaymentService implements PaymentService { ... }

// Platform-specific (selected on iOS)
@tomReflector
@TomComponent(PaymentService)
@platformIos
class ApplePayService implements PaymentService { ... }

// Environment-specific (selected in production)
@tomReflector
@TomComponent(PaymentService)
@TomEnvironment('production')
class StripePaymentService implements PaymentService { ... }

// Exact match (selected on iOS in production)
@tomReflector
@TomComponent(PaymentService)
@platformIos
@TomEnvironment('production')
class IosProductionPaymentService implements PaymentService { ... }
```

## Startup validation

The last step of `initializeBeanContext()` resolves the pending handles, so a
missing binding is reported at boot rather than at the first call that needed
it. A pending handle is any `TomBean` constructed since the previous pass (or
since `resetBeanContext()`) — including one constructed *between* two passes,
which the next pass validates. Whether a dependency is checked does not depend
on which side of an `initializeBeanContext()` call it was declared on.

Validation vouches for what the pass could itself have supplied. Discovery
registers under `Type` keys only: a concrete bean under its runtime type, an
interface implementation under the interface. So a **typed** handle still
unresolvable at the end of the pass names a binding nothing produced — a wiring
bug, reported as `no_bean_found_uninitialized`:

```dart
final missing = TomBean<UnregisteredService>();
initializeBeanContext();   // throws: nothing registers UnregisteredService
```

A handle **awaiting a named registration** is skipped. Nothing in discovery ever
registers a name — names enter the registry solely through `TomBean.withName` —
so resolving such a handle here would demand at boot something the pass has no
way to provide, and would turn the supported "create the handle now, register
the bean later" pattern into a startup failure:

```dart
final config = TomBean<AppConfig>.fromName('lateConfig');

initializeBeanContext();   // fine: the name is simply not registered yet

TomBean.withName('lateConfig', AppConfig());
config.get();              // resolves
```

The skip is narrow. A named handle whose name **is** registered is validated
like any other, so a name bound to an instance of the wrong type still fails at
boot with `bean_not_found_by_type` — that question is answerable now, and no
later registration repairs a mismatch.

## Error Handling

### TomBeanLocatorException

All bean locator errors throw `TomBeanLocatorException`:

```dart
try {
  final service = TomBean<NonExistentService>().get();
} on TomBeanLocatorException catch (e) {
  print('Error key: ${e.key}');
  print('Message: ${e.defaultUserMessage}');
}
```

### Error Keys

Every failure inside the bean locator arrives as a `TomBeanLocatorException`,
including the ones that originate one layer down — an unconfigured runtime is
translated at the boundary rather than surfacing `TomRuntime`'s own exception,
so the handler above is sufficient and does not need a second `catch`.

| Key | Description |
|-----|-------------|
| `beanlocator.initialization.duplicate_bean_with_name` | Duplicate named bean registration via `TomBean.withName`. To replace a binding deliberately, see [Substituting an Implementation](#substituting-an-implementation) |
| `beanlocator.initialization.duplicate_bean_with_type` | Duplicate typed bean registration via `TomBean.withType` — including a type discovery has already bound. To replace a binding deliberately, see [Substituting an Implementation](#substituting-an-implementation) |
| `beanlocator.initialization.no_matching_implementation_found` | Every implementation of an interface was ruled out by its `@TomEnvironment` or `@TomPlatform` selector, leaving discovery nothing to bind — see [Environment-Specific Beans](#environment-specific-beans) |
| `beanlocator.initialization.ambiguous_implementation` | Two implementations qualify equally for one interface — distinguish them with `@TomEnvironment` / `@TomPlatform`, or remove one |
| `beanlocator.bean_access.bean_not_found_by_name` | Named bean not found. Raised on `get()`, never by [startup validation](#startup-validation) — a name that is not registered yet is a supported state |
| `beanlocator.bean_access.bean_not_found_by_type` | Type mismatch for named bean. Also raised by [startup validation](#startup-validation), since the name is registered and the mismatch is answerable at boot |
| `beanlocator.bean_access.no_bean_found_uninitialized` | Bean type not registered. Also raised by [startup validation](#startup-validation) for a typed handle nothing bound |
| `beanlocator.bean_access.more_than_one_implementation_found` | More than one registered bean satisfies the requested type. Raised on *every* `get()` — a handle that failed to resolve caches nothing, so the ambiguity never wears down into an arbitrary answer |
| `beanlocator.bean_access.no_bean_found_unknown_error` | The type walk failed for a reason the locator does not model; the cause travels as the root exception |
| `beanlocator.environment.no_factory_for_environment` | `installByEnvironment` has no factory for the active environment |
| `beanlocator.environment.runtime_environment_not_initialized` | An operation needed the active environment and the runtime was never configured — see [Initialize in Correct Sequence](#1-initialize-in-correct-sequence). The `operation` and `subject` parameters name what was being wired |

### The runtime must be configured before the bean context

Environment selection reads the active environment from `TomRuntime`, so
anything that consults a selector requires a configured runtime:
`installByEnvironment` without an explicit `environment:`, discovery of a class
carrying `@TomEnvironment`, and the four-tier interface selection. Each of them
raises `beanlocator.environment.runtime_environment_not_initialized` naming the
bean or interface it was resolving.

The lookup is deliberately not hoisted: a bean that carries no selector is
discovered without a configured runtime, and passing `environment:` explicitly
answers the question the runtime would have been asked. Only code that actually
depends on the active environment is required to have one.

## Best Practices

### 1. Initialize in Correct Sequence

The initialization order is critical:

```dart
void main() {
  // 1. Set environment variables FIRST
  TomPlatformUtils.envVars["env"] = "dev";
  
  // 2. Set platform utilities
  TomPlatformUtils.setCurrentPlatform(myPlatformUtils);
  
  // 3. Initialize reflection
  initializeReflection();
  
  // 4. Initialize runtime
  initializeRuntime();
  
  // 5. Initialize bean context LAST (requires runtime to be ready)
  initializeBeanContext();

  // Only now start the application — runApp() in a Flutter app.
  startApplication();
}
```

### 2. Prefer Interfaces

Register an implementation under the interface it fulfils. Consumers then depend
on the interface, and a test can bind a different implementation without
touching them:

```dart
@tomReflector
@TomComponent(UserRepository)
class SqlUserRepository implements UserRepository { ... }

final users = TomBean<UserRepository>().get();
```

Registering the same class by its concrete type is less flexible: every consumer
names the implementation, so substituting another one means editing all of them.

```dart
@tomReflector
@tomComponent
class SqlUserRepository { ... }

final users = TomBean<SqlUserRepository>().get();
```

### 3. Store Bean References

For frequently accessed beans, store the handle:

```dart
// Class field
class MyController {
  final _userService = TomBean<UserService>();
  
  void doSomething() {
    // Efficient: Resolution cached after first call
    _userService().performAction();
  }
}
```

### 4. Use Specific Environments

Create environment hierarchies for configuration:

```dart
// Base configuration
const baseEnv = TomEnvironment('base');

// Environment-specific overrides
const devEnv = TomEnvironment('dev', parent: baseEnv, isDevelopment: true);
const prodEnv = TomEnvironment('prod', parent: baseEnv);
```

### 5. No Bean Resolution in Constructors

The bean locator uses lazy resolution, but circular dependencies during construction will fail:

```dart
// Avoid: ServiceA constructor calls TomBean<ServiceB>().get()
//        while ServiceB constructor calls TomBean<ServiceA>().get()

// Better: Never use any TomBean-based component inside of any of the constructors 
// of the beans. All TomBean-components must have a simple no-args constructor!
//
```

### 6. For Client/Flutter Apps: Use Environment-Specific main_xxx.dart Files

To avoid changes to the code for deployment it is most convenient to have separate files for each environment which prepares the environment setting and then call the main()-method of the actual main.dart-File:

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'main.dart' as app;


// Application main
void main() {
  // 1. Set environment variable (before anything else)
  TomPlatformUtils.envVars["env"] = "dev"; 

  // here you can also set other values (e.g. default user/password for dev-environment)
  
  app.main();

}
```

---

## Dependencies

This module depends on:

- [**Runtime System**](../../../../basics/tom_basics/doc/runtime/runtime.md) (`tom_basics`): `TomEnvironment` and `TomPlatform` for environment and platform-specific bean selection
- `package:tom_reflection`: `tomReflector` and `ClassMirror`, imported directly by `bean_locator.dart` — the kernel's Reflection Module below defines its own types *on* that package rather than re-exporting it, so a caller of the mirrors needs both
- [**Reflection Module**](../reflection/reflection.md): For bean discovery and instantiation via reflection
- [**Little Things Module**](../little_things/little_things.md): `TomException`, the base of `TomBeanLocatorException`
