# tom_core_agentic

Generic, domain-free building blocks for agentic systems in the TOM
framework. Everything here depends only on `tom_basics` (plus `yaml` /
`yaml_edit` for the config read/write path, `crypto` for the
content-hash convention, and `path` for the `PathScope` sandbox) and is
safe to reuse across the brain, the
assistant, and any future agent runtime.

## `dart:io` coupling

The package as a whole is **not** `dart:io`-free and does not claim to
be. Fourteen files under `lib/` import `dart:io`, and five of the
thirty-six barrel exports reach one of them — directly or transitively:

| Coupled barrel export | Reached through |
|-----------------------|-----------------|
| `src/agent/agent.dart` | eleven file-backed stores, `agent_send.dart`, `agent_sidecar.dart`, `bridge_connection.dart` |
| `src/llm/llm.dart` | `agent_sdk_session.dart` (subprocess transport) |
| `src/path_scope_io.dart` | itself — it *is* the `dart:io` half of `PathScope`, by design |
| `src/placeholders/placeholders.dart` | `placeholder_resolver.dart` (`Platform.environment` default) |
| `src/yaml_config_reader.dart` | `placeholder_resolver.dart`, via `${…}` expansion |

The remaining **31 exports are `dart:io`-free**, and that subset is what
makes the package usable from `dart:io`-forbidding consumers. The one in
the tree today, `tom_brain_shared`, uses seven symbols
(`requireNonEmpty`, `textPreview`, and the five `collection_equality`
helpers), all of which live in that subset.

**The failure mode is a runtime one, not a build one.** On the current
SDK `dart compile js` does not reject `dart:io`: it compiles, stubs the
library, and throws `UnsupportedError` when a stubbed member is actually
reached. A web consumer can therefore import the barrel — even `show` a
symbol from a coupled export — and only discover the problem when the
coupled code path runs. That is precisely why the split above is pinned
by `test/dart_io_coupling_test.dart` rather than by prose: the compiler
will not catch a regression here, so a test has to.

`PlaceholderResolver` is the one coupling that is incidental rather than
inherent — it needs `dart:io` only to default `environment` to
`Platform.environment`. Passing an explicit `environment:` map avoids
touching the stub at runtime, which every config-layer call site and
every test already does. Removing the import outright is tracked in
`deferred.tom_core.md`; it would also un-couple `yaml_config_reader.dart`,
which is coupled solely through it.

## What lives here

| Building block | Purpose |
|----------------|---------|
| `CancellationToken` / `CancellationTokenSource` | Cooperative cancellation for long-running async work. |
| `OperationCancelled` | Public exception thrown when a cancelled token is observed. |
| `CloseGuard` | Mixin that tracks a `isClosed` flag and throws on use-after-close. |
| `buildUniqueById` | Build an id-keyed map from a list, rejecting duplicate ids. |
| `textPreview` | Single-line, length-bounded preview of arbitrary text. |
| `HttpDate` | RFC 7231 / RFC 1123 HTTP-date parsing and formatting. |
| `CategoryLog` | Category-tag facade over the global `tomLog` (prepends `[category]`, forwards every level). |
| `systemClock` | The `DateTime.now` default for injectable `DateTime Function()` clock seams. |
| `AsyncShutdownCoordinator<S>` | Signal → awaited async teardown → terminate; `dart:io`-free, generic over the trigger type. |
| `loadYamlAsMap` / `expandEnvVars` | YAML → plain `Map<String, Object?>` parse boundary, plus `${ENV}` expansion. |
| `YamlConfigReader` / `MapFieldReader` | Typed, dotted-path reads over **plain** config maps (no `YamlMap` in the read path). |
| `YamlConfigWriter` | The sanctioned AST-preserving config writer (surgical `set`/`remove` over `yaml_edit`; keeps comments, order, formatting). |
| `percentileDuration` / `LatencySummary` | Nearest-rank percentile maths and a count/min/max/p50/p95 summary over `Duration` samples. |

## Integration with `tom_basics` / `tom_core_*` (reuse vs own)

This package sits in the **lightweight tier**: it depends only on
`tom_basics` and never on `tom_core_kernel` (which pulls `dart:io`,
`tom_reflection`, `http`, and a SQL client). The table below records,
per audited concern, whether the primitive is **reused** from
`tom_basics` or **owned** here — and, where a heavier `tom_core_*`
analogue exists, why it is not reused.

| Concern | Disposition | Detail |
|---------|-------------|--------|
| **Logging** | **Reuse** `tom_basics` | `CategoryLog` and `AsyncShutdownCoordinator` forward to the global `tomLog` (`TomLogger` / `TomLogLevel`). No second logger is implemented. `CategoryLog` is a forwarding facade, not a re-implementation. |
| **Clock** | **Own** (no equivalent) | Neither `tom_basics` nor `tom_core_kernel` ships a clock. `systemClock` is the one-line `DateTime.now` tear-off used as the default for injectable clock seams. |
| **Shutdown** | **Own by tier-design** | `tom_core_kernel` ships `TomShutdownCleanup`, but it imports `dart:io` (`ProcessSignal`) and `tom_reflection/mirrors`, so it lives in the heavy kernel tier. `AsyncShutdownCoordinator` is the `dart:io`-free, async-await-correct, trigger-generic coordinator the lightweight tier needs. Depending on the kernel to share it would drag `dart:io` + reflection into `tom_brain_shared`; the bounded duplication is intentional. |
| **Config read/write** | **Own** (no equivalent) | No YAML config loader/reader/writer exists in `tom_basics` or `tom_core_kernel`. `loadYamlAsMap` + `YamlConfigReader`/`MapFieldReader` own the read path (plain maps, no `YamlMap` leak); `YamlConfigWriter` owns the AST-preserving write path. |

**Audit result:** no divergent re-implementation
of a `tom_core_kernel`-owned primitive was found. Logging is reused;
clock and config helpers have no `tom_core_*` equivalent; the shutdown
coordinator is a deliberate lightweight-tier alternative to the kernel's
`dart:io`-coupled `TomShutdownCleanup`. The audited helpers
(`CategoryLog`, `systemClock`, `AsyncShutdownCoordinator`,
`YamlConfigReader`/`MapFieldReader`/`YamlConfigWriter`) keep their
existing unit tests.

## Runnable examples

Four programs under [`example/`](example/), one per module that has a surface
worth driving directly:

| Example | Demonstrates |
| ------- | ------------ |
| [`example/placeholders/`](example/placeholders/placeholders_example.dart) | The placeholder forms, both entry points, the lexical scope stack, transitive recursion and the typed failures |
| [`example/lifecycle_guards/`](example/lifecycle_guards/lifecycle_guards_example.dart) | Cooperative cancellation and the close-guard family |
| [`example/isolate_streaming/`](example/isolate_streaming/isolate_streaming_example.dart) | Streaming results back across an isolate boundary |
| [`example/mcp_auth/`](example/mcp_auth/mcp_auth_example.dart) | Bearer-token verification and the principal it resolves |

**Run them with the flag their headers name:**

```bash
dart run --enable-asserts example/placeholders/placeholders_example.dart
```

`--enable-asserts` is not optional. Each example states its expectations with
`assert`, and `dart run` leaves assertions *disabled* — that is what the flag is
for — so under a flagless run every expectation would compile out and the
example would print its transcript and exit 0 having verified nothing. It
refuses instead: each example opens by checking that asserts are on, and exits
with status 2 and the corrected command if they are not.

`test/examples_test.dart` holds all three parts: it runs every example under
exactly the command its header names, it requires every header to name that
command — a sweep that passes a flag the header omits proves nothing about what
a reader will see — and it requires every example to refuse a flagless run.
(`tom_core_server` answers the same question the other way, with a helper that
throws instead of asserting; either is sound, and documenting one while
verifying the other is not. `tom_core_kernel`'s samples refuse a flagless run
the same way these do.)

## What does NOT live here

Anything brain- or domain-specific. The `sha256:<hex>` prompt-hash
convention and the `BrainEventBus<E>` live in `tom_brain_shared`;
retry / circuit-breaker transport policy lives in `tom_core_kernel`.
