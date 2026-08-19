# tom_core_kernel

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

> **⚠️ Work in progress — unstable API.** The Tom Core packages are under active
> development and not yet stable. Their version numbers carry no promise about
> API maturity: they are publishing counters, not semver. The patch number is
> bumped on every change — **including breaking changes** — so a patch bump may
> break you. Expect the public surface to shift without notice. Not recommended
> for production use yet.

Core kernel library for the Tom Framework — the platform-neutral building blocks
every other Tom layer is composed from.

## Overview

`tom_core_kernel` is the foundation of the Tom Framework. It carries no UI and no
server runtime, so it runs unchanged on any Dart target — CLI, server, Flutter,
or the [`d4rt`](../tom_core_d4rt/README.md) interpreter. Everything layered above
it (the [server stack](../tom_core_server/README.md), the
[Flutter](../tom_core_flutter/README.md) /
[UI](../tom_flutter_ui/README.md) layers, the DartScript bridge) depends on the
contracts defined here.

The kernel is **reflection-aware**: it builds on
[`tom_reflection`](../../reflection/tom_reflection/README.md) so observable
objects, security principals, and resource trees can be introspected and
serialized without hand-written boilerplate. Conceptually it provides five things:

- **Observable state** — values and objects that notify observers on change, with
  a terse operator syntax (`|` set, `~` read, `>>` observe).
- **Ambient context** — zone-propagated execution context and hierarchical
  scope identifiers, so a deeply nested call can resolve "where am I" without
  threading parameters through every frame.
- **Dependency injection** — a reflection-driven bean container.
- **Security** — authentication, a layered access-control model, bearer-token
  auth, and a four-state authorization model (`TomAuthState`).
- **Runtime utilities** — logging (including isolate/remote), an isolate worker
  pool, a durable job scheduler, the canonical success-or-error result
  envelope, JSON tree helpers, resource providers, settings, timezone-aware
  timestamps, and ordered shutdown.

## Installation

This package is internal to the Tom workspace and consumed by path (it is
`publish_to: none`), so there is no `dart pub add` line. Add it as a path
dependency:

```yaml
dependencies:
  tom_core_kernel:
    path: ../tom_core_kernel
```

Then import the single barrel:

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';
```

The barrel re-exports [`tom_basics`](../../basics/tom_basics/README.md),
[`tom_crypto`](../../basics/tom_crypto/README.md) and
[`tom_reflection`](../../reflection/tom_reflection/README.md), so one import
covers the common surface. **SDK:** Dart `^3.10.0`. Modules that use reflection
require a `dart run build_runner build` to generate `*.reflection.dart`.

## Features

### Observable state (`observable`)

| Type | Responsibility |
| ---- | -------------- |
| `TomObject<T>` | Base observable holding a single typed value |
| `TomString` / `TomInt` / `TomDouble` / `TomBool` | Typed scalar observables |
| `TomClass` / `TomList` / `TomMap` | Observable composites |

### Context & scope (`context`, `scope_ids`)

| Type | Responsibility |
| ---- | -------------- |
| `TomExecutionContext` | Ambient, zone-propagated execution context |
| `TomContextEntry<T>` | A typed value carried on the context |
| `TomScope` / `InScopeBuilder` | Hierarchical, zone-propagated scope identifiers |

### Dependency injection (`beanlocator`)

| Type | Responsibility |
| ---- | -------------- |
| `TomComponent` | The discovery annotation, carrying the interface `Type` the annotated class registers under |
| `TomBean<T>` | Typed handle that resolves its bean lazily, by type or by name |
| `TomNoInterface` | The `Type` `@tomComponent` carries, for a bean registered under its own type |

`initializeBeanContext()` runs the discovery pass: it finds the
`@TomComponent`-annotated classes, selects one implementation per interface for
the active environment and platform, instantiates it, and then resolves every
handle declared so far so a missing binding fails at start-up.

### Security (`security`)

| Type | Responsibility |
| ---- | -------------- |
| `TomAuthorization` / `TomAuthState` | Authorization decisions and the four-state model |
| `TomAccessControl` (+ `TomNoAccess`, `TomPublicAccess`, `TomAuthenticatedAccess`, `TomGuestAccess`) | Layered access-control rules |
| `TomBearerAuthentication` | Bearer-token authentication |
| `TomAccessControlInformation`, `TomGroup`, `TomRole`, `TomEntitlement` | Principal / ACI model |
| `tomOAuthApi`, `TomOAuthProviderDto`, `TomOAuthAuthorizationRequest`, `TomOAuthCallbackRequest`, `TomOAuthApiService` | The wire contract for external-identity login ("Sign in with …"). The `/oauth/callback` endpoint answers with `TomAuthenticationResult` — the *same* type `/login` answers with, because an OAuth provider resolves a principal and everything after that is the one login path every credential reaches, second factor included. |

### Runtime utilities

| Module | Key types | What it does |
| ------ | --------- | ------------ |
| `logging` | isolate & remote log output/server | Structured logging across isolates and the wire |
| `isolate_pooling` | `TomWorker`, `TomWorkerPool`, `TomExecutor`, `TomCommand` | Worker-pool execution across isolates |
| `scheduling` | `TomScheduler`, `TomJobDefinition`, `TomSchedule` (cron / calendar / interval / once / event), `TomJobStore`, `TomLeaseLock` | Durable, leased job scheduling with retry and catch-up policies |
| `json` | map-merge, pretty-print helpers | JSON tree merge/serialization utilities |
| `result` | `TomResult<T>`, `TomErrorResult`, `TomFieldError`, `TomErrorSeverity` | The canonical success-or-error envelope every operation returns |
| `resources` | `TomTextResourceProvider`, `TomConfigResourceProvider` | Text and configuration resource resolution |
| `settings` | client settings/authorization | Settings management |
| `preferences` | `TomUserPreferenceKeys`, `TomUserPreferenceDto`, `TomUserPreferenceCodec`, `tomUserPreferencesApi` | The contract both preference stores bind to: well-known keys, wire DTOs, the value codec, and the `/preferences` API |
| `shutdown_cleanup` | `TomShutdownCleanup`, `TomDisposable`, `TomClosable` | Ordered shutdown / cleanup hooks |
| `timezoned` | `DateTimestamp`, timezone tables | Timezone-aware date/time |
| `http_connection` | server connection, endpoints, headers | HTTP connection helpers |
| `little_things` | zone helpers, formatting, `TomException` | Small cross-cutting utilities |
| `reflection` | reflection bootstrap | Reflection support built on `tom_reflection` |

## Quick start

Observable state with automatic observer propagation:

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  final count = TomInt(0);
  count >> (obs) => print('changed to ${~count}');
  count | 5; // prints: changed to 5
}
```

`|` sets the value, `~` reads it, and `>>` registers an observer that fires on
every change.

## Example projects

Every module ships a runnable sample folder under
[`example/samples/`](example/samples/), and the top-level
[`run_all_samples.dart`](example/run_all_samples.dart) runs the whole set in
sequence. That is the only example tree — each folder's
`00_run_all_examples.dart` both stands alone and is called by the master runner,
so anything listed below is executed on every run.

| Sample | Demonstrates |
| ------ | ------------ |
| [`example/samples/observable/`](example/samples/observable/) | Observable scalars, composites, and observers |
| [`example/samples/beanlocator/`](example/samples/beanlocator/) | Registering and locating beans |
| [`example/samples/context/`](example/samples/context/) | Execution context & context entries |
| [`example/samples/scope_ids/`](example/samples/scope_ids/) | Hierarchical scope paths |
| [`example/samples/security/`](example/samples/security/) | Access controls, authorization, bearer auth |
| [`example/samples/crypto/`](example/samples/crypto/) | JWT / hashing helpers (via `tom_crypto`) |
| [`example/samples/runtime/`](example/samples/runtime/) | Environment / platform detection (via `tom_basics`) |
| [`example/samples/isolate_pooling/`](example/samples/isolate_pooling/) | Worker-pool execution |
| [`example/samples/logging/`](example/samples/logging/) | Structured / isolate / remote logging |
| [`example/samples/resources/`](example/samples/resources/) | Text & config resource providers |
| [`example/samples/result/`](example/samples/result/) | The success-or-error envelope, error details, and its wire form |
| [`example/samples/preferences/`](example/samples/preferences/) | The preference codec's scalar, `DateTime` and reflected round-trips, and the `/preferences` contract |
| [`example/samples/scheduling/`](example/samples/scheduling/) | The in-memory substrate, `@TomScheduledJob` discovery, every schedule kind against the missed-window policies, and what at-least-once asks of a job body |
| [`example/samples/json/`](example/samples/json/) · [`example/samples/timezoned/`](example/samples/timezoned/) · [`example/samples/settings/`](example/samples/settings/) · [`example/samples/shutdown_cleanup/`](example/samples/shutdown_cleanup/) · [`example/samples/http_connection/`](example/samples/http_connection/) · [`example/samples/little_things/`](example/samples/little_things/) · [`example/samples/reflection/`](example/samples/reflection/) | The remaining utility modules |

Run the whole set:

```bash
dart run build_runner build      # generate reflection (once / on signature change)
dart run --enable-asserts example/run_all_samples.dart
```

`--enable-asserts` is not optional. The samples check themselves with `assert`,
and Dart compiles asserts away unless the flag is passed — without it the
examples still print their output and still exit 0, but nothing they claim is
actually verified.

> **Cross-package sample.** Beyond these per-module examples, the shared
> [`tom_core_samples/todo_domain`](../tom_core_samples/todo_domain/readme.md)
> project models one todo-management domain on this kernel's reflection — the
> single entity set every Tom Core sample reuses. See the
> [samples map](../tom_core_samples/README.md) for the full learning path.

## Usage

### Namespacing with zone-propagated scopes

```dart
TomScope.withScope('checkout', () {
  TomScope.withScope('orderForm', () {
    print(TomScope.current.getScopePath()); // checkout.orderForm
  });
});
```

### Resolving text resources

```dart
TomTextResourceProvider.setAppResourceProvider(
  TomTextResourceProvider.from({'greeting': 'Hello, {name}!'}),
);
```

### Locating a bean

`initializeBeanContext()` discovers the classes annotated `@TomComponent`,
selects one implementation per interface for the active environment and
platform, and instantiates it. A consumer then holds a `TomBean<T>` handle,
which resolves itself on first use:

```dart
@tomReflector
@TomComponent(UserService)
class UserServiceImpl implements UserService { /* … */ }

class OrderService {
  final TomBean<UserService> users = TomBean();

  Order create(int userId) => Order(users().getUser(userId));
}
```

Nothing is injected into a bean: it is built through its unnamed no-argument
constructor, and each handle it declares resolves on its own. What discovery
does provide is the *choice* — which implementation a deployment gets — and a
start-up check that every declared handle can be resolved.

### Ordered shutdown

`TomShutdownCleanup` registers `TomDisposable` / `TomClosable` resources and
tears them down in a deterministic order on process exit.

## Architecture

```
                tom_core_kernel
                      │
   ┌──────────┬───────┼────────┬───────────┐
observable  context  security  resources   runtime utils
 (TomObject) (scope) (TomAuth*) (providers) (logging, isolates,
                                             json, settings,
                                             shutdown, timezoned)
                      │
              tom_reflection  ← introspection / serialization
              tom_basics · tom_crypto
```

The kernel is a single package with one barrel; modules live under
`lib/src/tombase/<module>/` and are mutually low-coupled — context/scope and
observable underpin the rest, security builds on both, and the runtime utilities
are largely independent.

| Type | Responsibility |
| ---- | -------------- |
| `TomObject<T>` | Observable value, the unit of reactive state |
| `TomScope` | Zone-propagated hierarchical scope identifier |
| `TomExecutionContext` | Ambient context carried through a call tree |
| `TomAuthorization` / `TomAuthState` | Authorization decision + four-state model |
| `TomAccessControl` | Base access-control rule |
| `TomBean<T>` / `TomComponent` | Lazily resolved bean handle / the discovery annotation |
| `TomWorker` / `TomWorkerPool` | Isolate worker-pool execution |
| `TomTextResourceProvider` | Text resource resolution |
| `TomShutdownCleanup` | Ordered teardown registry |

## Ecosystem

```
tom_basics · tom_crypto · tom_reflection
                 │
          tom_core_kernel        ← you are here
        ┌────────┼─────────┐
tom_core_server  tom_core_flutter  tom_core_d4rt
                 │                   (bridges the kernel into d4rt scripts)
          tom_flutter_ui
```

`tom_core_kernel` sits directly on the basics/crypto/reflection foundation and is
the common dependency of the server, Flutter, and DartScript layers. See the
[repository map](../README.md) for the full picture.

## Further documentation

- Per-module guides under [`doc/`](doc/) — one folder per module
  (`doc/observable/`, `doc/security/`, `doc/scope_ids/`, …).
- [`doc/scheduling/scheduling.md`](doc/scheduling/scheduling.md) — the job
  scheduler: schedule kinds, retry and missed-window policies, the job store,
  and the lease lock that keeps one owner per job across processes.
- [`doc/result/result.md`](doc/result/result.md) — the result envelope: why an
  application outcome is not an HTTP error, and how error codes key client copy.
- Per-module API reference under [`doc/api_reference/`](doc/api_reference/) —
  one summary per barrel-exported module plus a cross-module type index; start at
  [`api_summary_index.md`](doc/api_reference/api_summary_index.md).
- [`tom_basics/doc/runtime/runtime.md`](../../basics/tom_basics/doc/runtime/runtime.md)
  — the runtime guide (`TomEnvironment`, `TomPlatform`, `TomRuntime`). The code
  lives in `tom_basics`; the kernel barrel re-exports it.
- [`tom_core_server`](../tom_core_server/README.md) — the server runtime built on
  this kernel.
- [`tom_core_flutter`](../tom_core_flutter/README.md) /
  [`tom_flutter_ui`](../tom_flutter_ui/README.md) — the client/UI layers.
- [`tom_core_d4rt`](../tom_core_d4rt/README.md) — exposes these types to `d4rt`
  scripts.

## Status

- **Version:** 1.1.1
- **Tests:** 2,128 test cases across 27 suites (run with `testkit :test`
  or `dart test`).
- **License:** BSD-3-Clause — see [LICENSE](LICENSE).
