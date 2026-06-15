# tom_core_agentic

Generic, domain-free building blocks for agentic systems in the TOM
framework. Everything here depends only on `tom_basics` (plus `yaml` /
`yaml_edit` for the config read/write path, `crypto` for the
content-hash convention, and `path` for the `PathScope` sandbox) and is
safe to reuse across the brain, the
assistant, and any future agent runtime. The package is deliberately
**`dart:io`-free**, so it stays usable from `dart:io`-forbidding
consumers such as `tom_brain_shared`.

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

**Audit result (prototype-plan-2 item 7):** no divergent re-implementation
of a `tom_core_kernel`-owned primitive was found. Logging is reused;
clock and config helpers have no `tom_core_*` equivalent; the shutdown
coordinator is a deliberate lightweight-tier alternative to the kernel's
`dart:io`-coupled `TomShutdownCleanup`. The audited helpers
(`CategoryLog`, `systemClock`, `AsyncShutdownCoordinator`,
`YamlConfigReader`/`MapFieldReader`/`YamlConfigWriter`) keep their
existing unit tests.

## What does NOT live here

Anything brain- or domain-specific. The `sha256:<hex>` prompt-hash
convention and the `BrainEventBus<E>` live in `tom_brain_shared`;
retry / circuit-breaker transport policy lives in `tom_core_kernel`.
