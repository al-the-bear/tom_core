# tom_core_kernel

Published on pub.dev as [`tom_core_kernel` 1.1.16](https://pub.dev/packages/tom_core_kernel).

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and published on pub.dev.

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
server runtime, so it runs unchanged on any Dart target — CLI, server, or
Flutter. Everything layered above it (the
[server stack](../tom_core_server/README.md), the
[Flutter](../tom_core_flutter/README.md) /
[UI](../tom_flutter_ui/README.md) layers) depends on the contracts defined here.

The kernel is **reflection-aware**: it builds on
[`tom_reflection`](../../reflection/tom_reflection/README.md) so observable
objects, security principals, and resource trees can be introspected and
serialized without hand-written boilerplate. Conceptually it provides five things:

- **Observable state** — values and objects that notify observers on change, with
  a terse operator syntax (`|` set, `~` read, `>>` observe).
- **Ambient context** — zone-propagated execution context, the tenant and the
  W3C trace a piece of work belongs to with the spans recorded in it when a
  tracer is installed, and hierarchical scope identifiers, so a deeply nested
  call can resolve "where am I" without threading parameters through every
  frame.
- **Dependency injection** — a reflection-driven bean container.
- **Security** — authentication, a layered access-control model, bearer-token
  auth, and a four-state authorization model (`TomAuthState`).
- **Runtime utilities** — logging (including isolate/remote, and structured
  JSON lines carrying the trace, span and tenant), an isolate worker
  pool, a durable job scheduler, in-process metrics exported to Prometheus
  and OTLP, the canonical success-or-error result
  envelope, JSON tree helpers, resource providers, settings, feature
  flags, timezone-aware timestamps, and ordered shutdown.
- **Offline data** — server entities kept on the device, every change queued
  with the version it was based on, and a sync that pushes, settles conflicts
  and pulls; the application supplies the device database.

## Installation

Add it from pub.dev:

```yaml
dependencies:
  tom_core_kernel: ^1.1.16
```

Then import the single barrel:

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';
```

The barrel is platform-neutral and compiles for the web. What needs a
filesystem — the cross-isolate, cross-process file guard (`tomWithFileLock`,
`tomWithFileLockAsync`) — is in a second entry library that only native code may
import:

```dart
import 'package:tom_core_kernel/tom_core_kernel_io.dart';
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
| `TomTenantContext` / `TomTenantScopedCommand` / `TomTenantEvent` | The tenant — an isolation boundary, not an organization — carried in the zone, into a job's body and across an isolate hop |
| `TomTraceContext` | The W3C trace and span the work belongs to, carried in the zone; parses and renders `traceparent` |
| `TomRequestId` | The id of the unit of work — a request, a job run, a socket message — carried in the zone beside its trace; every log line, server exception and audit entry of the work names it |
| `TomTracing` / `TomTracer` / `TomSpan` / `TomRecordingTracer` | Spans: the timed steps of a trace — a request, an SQL statement, a transaction, an outgoing call, a job run — recorded by an installed tracer, and nothing at all without one. `tom_core_server` provides the OpenTelemetry tracer |
| `TomScope` / `ScopeCapture` | Hierarchical, zone-propagated scope identifiers |

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
| `TomResourceRoleRegistry`, `TomResourceRoleAdapter` | Per-principal-per-resource roles — the same user as `owner` of one resource and `viewer` of another. The kernel's only shipped `TomAuthorizationAdapter` |
| `tomOAuthApi`, `TomOAuthProviderDto`, `TomOAuthAuthorizationRequest`, `TomOAuthCallbackRequest`, `TomOAuthApiService` | The wire contract for external-identity login ("Sign in with …"). The `/oauth/complete` endpoint — which the *application* calls, forwarding what the provider's redirect left on its own page — answers with `TomAuthenticationResult` — the *same* type `/login` answers with, because an OAuth provider resolves a principal and everything after that is the one login path every credential reaches, second factor included. |

### Runtime utilities

| Module | Key types | What it does |
| ------ | --------- | ------------ |
| `logging` | isolate & remote log output/server, `TomJsonLogOutput`, `TomLogContext` | Structured logging across isolates and the wire; one JSON object per line with the trace, span and tenant read from the zone |
| `isolate_pooling` | `TomWorker`, `TomWorkerPool`, `TomExecutor`, `TomCommand` | Worker-pool execution across isolates |
| `metrics` | `TomMetricRegistry`, `TomCounter`, `TomGauge`, `TomHistogram`, `TomMetrics.registry`, `tomPrometheusText` | Per-isolate counters, gauges, histograms and observed gauges; one snapshot rendered as Prometheus text and read by the server's OTLP exporter |
| `scheduling` | `TomScheduler`, `TomJobDefinition`, `TomSchedule` (cron / calendar / interval / once / event), `TomJobStore`, `TomLeaseLock` | Durable, leased job scheduling with retry and catch-up policies, job priorities, pausing, and checkpoints a run resumes from |
| `json` | map-merge, pretty-print helpers | JSON tree merge/serialization utilities |
| `resources` | `TomTextResourceProvider`, `TomConfigResourceProvider` | Text and configuration resource resolution |
| `settings` | `TomGetSettingsMessage`, `TomGetSettingsResult`, `TomFeatureFlags`, `TomRuleFlagProvider`, `TomFeatureFlagsClient` | The client-settings exchange, and feature flags: rules by tenant, role and stable percentage, read through an OpenFeature-shaped provider, and the `/feature-flags` API a client fetches its evaluated flags from |
| `offline` | `TomLocalStoreEngine`, `TomLocalRepository`, `TomOfflineStore`, `TomSyncEngine`, `TomSyncTransport`, `TomMemorySyncServer` | Server entities cached on the device: a repository whose every write is queued with its base version, and a sync that pushes under optimistic locking, hands conflicts to the application's resolver and pulls by the server's change sequence. The device database is the application's, behind `TomLocalStoreEngine` |
| `preferences` | `TomUserPreferenceKeys`, `TomUserPreferenceDto`, `TomUserPreferenceCodec`, `tomUserPreferencesApi` | The contract both preference stores bind to: well-known keys, wire DTOs, the value codec, and the `/preferences` API |
| `shutdown_cleanup` | `TomShutdownCleanup`, `TomDisposable`, `TomClosable` | Ordered shutdown / cleanup hooks |
| `timezoned` | `DateTimestamp`, timezone tables | Timezone-aware date/time |
| `http_connection` | server connection, endpoints, headers, `TomResilientClient`, `TomHttpResilience` | HTTP connection helpers; timeout, retries, circuit breaker and bulkhead per destination for every outgoing call |
| `little_things` | zone helpers, formatting, `TomException` | Small cross-cutting utilities |
| `reflection` | reflection bootstrap | Reflection support built on `tom_reflection` |

## Quick start

Observable state with automatic observer propagation:

```dart complete
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  final count = TomInt(0);
  final observer = count >> (obs) => print('changed to ${~count}');
  count | 5; // prints: changed to 5
  count.removeObserver(observer);
}
```

`|` sets the value, `~` reads it, and `>>` registers an observer that fires on
every change. Observers are held by weak reference, so keep the one `>>`
returns — an observer nothing references is collected and silently stops
firing. See
[`doc/observable/observable.md`](doc/observable/observable.md#memory-management--you-must-retain-the-observer).

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
| [`example/samples/context/`](example/samples/context/) | Execution context & context entries, and the W3C trace context |
| [`example/samples/scope_ids/`](example/samples/scope_ids/) | Hierarchical scope paths |
| [`example/samples/security/`](example/samples/security/) | Access controls, authorization, bearer auth |
| [`example/samples/crypto/`](example/samples/crypto/) | JWT / hashing helpers (via `tom_crypto`) |
| [`example/samples/runtime/`](example/samples/runtime/) | Environment / platform detection (via `tom_basics`) |
| [`example/samples/isolate_pooling/`](example/samples/isolate_pooling/) | Worker-pool execution |
| [`example/samples/logging/`](example/samples/logging/) | Structured / isolate / remote logging, and JSON lines with their context fields |
| [`example/samples/resources/`](example/samples/resources/) | Text & config resource providers |
| [`example/samples/preferences/`](example/samples/preferences/) | The preference codec's scalar, `DateTime` and reflected round-trips, and the `/preferences` contract |
| [`example/samples/metrics/`](example/samples/metrics/) | The three instruments and every misuse refused, the exact Prometheus text of a snapshot, and the `tom_job_*` series a scheduler records |
| [`example/samples/offline/`](example/samples/offline/) | A save offline, read back and queued; the push and its version; another client's change pulled; a deletion; a conflict settled by the application's merge |
| [`example/samples/scheduling/`](example/samples/scheduling/) | The in-memory substrate, `@TomScheduledJob` discovery, every schedule kind against the missed-window policies, what at-least-once asks of a job body, the file store across a restart, and priority, pausing and checkpoints |
| [`example/samples/json/`](example/samples/json/) · [`example/samples/timezoned/`](example/samples/timezoned/) · [`example/samples/settings/`](example/samples/settings/) · [`example/samples/shutdown_cleanup/`](example/samples/shutdown_cleanup/) · [`example/samples/http_connection/`](example/samples/http_connection/) · [`example/samples/little_things/`](example/samples/little_things/) · [`example/samples/reflection/`](example/samples/reflection/) | The remaining utility modules |

Run the whole set:

```bash
dart run build_runner build      # generate reflection (once / on signature change)
dart run --enable-asserts example/run_all_samples.dart
```

`--enable-asserts` is not optional. The samples check themselves with `assert`,
and Dart compiles asserts away unless the flag is passed — without it the
examples would still print their output and still exit 0, while verifying
nothing they claim. Rather than leave that trap open, every sample's `main()`
opens with `prepareSampleProcess()`
([`example/sample_preamble.dart`](example/sample_preamble.dart)), which prints
the correct command and exits `2` instead of running hollow.

That function is also where the process gets its platform identity. The
framework builds its log header from
`TomPlatformUtils.current.getIsolateName()`, and until something installs an
implementation the fallback answers with the empty string — so every framework
log line reads `<timestamp> - INFO …` rather than `<timestamp> main-main INFO
…`. Installing `TomStandalonePlatformUtils` in the shared preamble rather than
in the master runner is what makes the prefix uniform across all three ways of
starting a sample: the full run, a group runner, and a single file. No sample
configures it, and none has to.

Every sample also runs on its own, which is usually what you want while reading
one:

```bash
dart run --enable-asserts example/samples/observable/03_tom_class.dart
```

Samples that build reflected types call `bootstrapSamples()`
([`example/sample_bootstrap.dart`](example/sample_bootstrap.dart)) as the first
statement of their `main()` instead of `prepareSampleProcess()` — it does the
preamble and then installs the generated reflection registry, which is the one
place that happens. The rest reflect over nothing and skip it, because importing
the registry costs roughly three seconds of compile time per entry point. That
cost is also why the preamble lives in its own registry-free library: it lets
the non-reflecting samples be prepared without paying for a registry they never
touch.

The master runner cannot police the standalone path — it drives samples through
their group runners and ends in `exit(0)`, so a sample that has no `main()`,
never registers reflection, or never terminates is invisible to it.
[`tool/run_standalone_examples.sh`](tool/run_standalone_examples.sh) is the guard
for that. It runs every sample by itself under a watchdog, failing on a hang as
well as on a non-zero exit, and before the sweep it checks the commands this
package *hands out* — anywhere in it, not just in a sample header:

- every documented `dart run` command pointing into `example/` **names a file
  that exists**, which the sweep itself cannot check, since it finds samples with
  `find` rather than by reading the documentation;
- every one of them **passes `--enable-asserts`**, so a reader who copies the
  command gets a run that verifies something;
- every sample's `main()` **calls `prepareSampleProcess()`**, so a reader who
  types the command from memory and omits the flag is refused rather than shown
  a hollow green;
- every sample **contains at least one `assert`** — one that asserts nothing
  exits 0 whatever the API does, and has no verification for a missing flag to
  strip, so it slips past the check above as well;
- every sample **opens `run()` with `print('=== NN: Title ===\n')` carrying its
  own file number**, so that a reader watching a group runner's single
  continuous stream can tell which file each block came from. A sample that
  prints nothing contributes no block at all; one whose banner carries somebody
  else's number sends a reader to the wrong file, which is worse.
- every group runner **frames its stream with `sampleGroupHeader('<Group>')` and
  `sampleGroupFooter('<Group>')`** from `example/sample_bootstrap.dart` and
  prints no group chrome of its own, so a transcript of several groups shows one
  boundary shape throughout — `Running <Group> Examples...` and a rule, then the
  rule and `All <Group> examples completed successfully!` — and a new runner is
  written to that shape by calling the pair, not by copying a neighbour;

And after the sweep, one check that reads its output rather than the source:
every sample **appears in its own group's stream**. The check above sees a
banner anywhere in the file, which is not the same thing — a banner in `main()`
names the sample on the standalone path and leaves it anonymous inside the group
runner, which calls `run()`. Reading the group runners' logs is what tells the
two apart, and the sweep has just produced them.

```bash
./tool/run_standalone_examples.sh              # all of them
./tool/run_standalone_examples.sh observable   # one group
```

The group argument narrows the *sweep* only — the five static checks always cover
the whole package, because a wrong command is wrong for every reader, not only
for the group under test. The stream check necessarily follows the sweep, so it
covers whichever groups ran.

> **Cross-package sample.** Beyond these per-module examples, the shared
> [`tom_core_samples/todo_domain`](../tom_core_samples/todo_domain/README.md)
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
                                             json, settings, metrics,
                                             offline, shutdown, timezoned)
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
        ┌────────┴─────────┐
tom_core_server  tom_core_flutter
                 │
          tom_flutter_ui
```

`tom_core_kernel` sits directly on the basics/crypto/reflection foundation and is
the common dependency of the server and Flutter layers. See the
[repository map](../README.md) for the full picture.

## Further documentation

- Per-module guides under [`doc/`](doc/) — one folder per module
  (`doc/observable/`, `doc/security/`, `doc/scope_ids/`, …).
- [`doc/scheduling/scheduling.md`](doc/scheduling/scheduling.md) — the job
  scheduler: schedule kinds, retry and missed-window policies, priority,
  pausing and checkpoints, the job store, and the lease lock that keeps one owner per job across processes.
- [`doc/metrics/metrics.md`](doc/metrics/metrics.md) — counters, gauges,
  histograms and observed gauges, the snapshot both exporters read, and the
  series the framework records.
- [`doc/offline/offline.md`](doc/offline/offline.md) — the device-side
  repository, the queue of pending changes, the sync flow and conflict
  resolution, the protocol's server side, and writing an engine adapter.
- Per-module API reference under [`doc/api/`](doc/api/) —
  one summary per barrel-exported module plus a cross-module type index; start at
  [`api_summary_index.md`](doc/api/api_summary_index.md).
- [`tom_basics/doc/runtime/runtime.md`](../../basics/tom_basics/doc/runtime/runtime.md)
  — the runtime guide (`TomEnvironment`, `TomPlatform`, `TomRuntime`). The code
  lives in `tom_basics`; the kernel barrel re-exports it.
- [`tom_core_server`](../tom_core_server/README.md) — the server runtime built on
  this kernel.
- [`tom_core_flutter`](../tom_core_flutter/README.md) /
  [`tom_flutter_ui`](../tom_flutter_ui/README.md) — the client/UI layers.

## Status

- **Version:** 1.1.16
- **Tests:** run with `testkit :test` or `dart test`. No count is given: a
  count is a claim nothing checks, and every added test would be a README edit
  nobody makes. The version above is checked, because a wrong one is the claim
  that actively misleads.
- **License:** BSD-3-Clause — see [LICENSE](LICENSE).
