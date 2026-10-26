# tom_core_agentic

Generic, domain-free building blocks for agentic systems in the TOM
framework. Everything here depends only on `tom_basics` (plus `yaml` /
`yaml_edit` for the config read path and the agent YAML, and `path` for
the `PathScope` sandbox) and is safe to reuse across the brain, the
assistant, and any future agent runtime.

Cooperative cancellation (`TomCancellationToken`, `TomCancellationSource`,
`TomOperationCancelled`), the AST-preserving YAML config writer
(`TomYamlConfigWriter`) and the SHA-256 behind `promptSha256`
(`tomSha256OfText`) are `tom_basics`' (`package:tom_basics/utilities.dart`).
This package uses them and declares none of them; import them from there.

## `dart:io` coupling

The package as a whole is **not** `dart:io`-free and does not claim to
be. 15 files under `lib/` import `dart:io`, and 5 of the 34 barrel
exports reach one of them — directly or transitively:

| Coupled barrel export | Reaches | Through |
|-----------------------|--------:|---------|
| `src/agent/agent.dart` | 13 | nine file-backed stores, `agent_send.dart`, `agent_sidecar.dart`, `bridge_connection.dart`, and `placeholder_resolver.dart` through the editor placeholder bindings |
| `src/llm/llm.dart` | 1 | `agent_sdk_session.dart` (subprocess transport) |
| `src/path_scope_io.dart` | 1 | itself — it *is* the `dart:io` half of `PathScope`, by design |
| `src/placeholders/placeholders.dart` | 1 | `placeholder_resolver.dart` (`Platform.environment` default) |
| `src/yaml_config_reader.dart` | 1 | `placeholder_resolver.dart`, via `${…}` expansion |

Every figure above is derived by `test/dart_io_coupling_test.dart`, which
reads this section and fails when a number here stops matching the import
graph. The counts were prose once and went stale the first time a module
gained an import.

The remaining **29 exports are `dart:io`-free**, and that subset is what
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
every test already does. Removing the import outright is deferred rather than
planned — it would also un-couple `yaml_config_reader.dart`, which reaches
`dart:io` solely through this one import, so the change is worth more than it
looks and is still not urgent.

## What lives here

| Building block | Purpose |
|----------------|---------|
| `CloseGuard` | Mixin that tracks a `isClosed` flag and throws on use-after-close. |
| `buildUniqueById` | Build an id-keyed map from a list, rejecting duplicate ids. |
| `textPreview` | Single-line, length-bounded preview of arbitrary text. |
| `HttpDate` | RFC 7231 / RFC 1123 HTTP-date parsing and formatting. |
| `CategoryLog` | Category-tag facade over the global `tomLog` (prepends `[category]`, forwards every level). |
| `systemClock` | The `DateTime.now` default for injectable `DateTime Function()` clock seams. |
| `AsyncShutdownCoordinator<S>` | Signal → awaited async teardown → terminate; `dart:io`-free, generic over the trigger type. |
| `loadYamlAsMap` / `expandEnvVars` | YAML → plain `Map<String, Object?>` parse boundary, plus `${ENV}` expansion. |
| `YamlConfigReader` / `MapFieldReader` | Typed, dotted-path reads over **plain** config maps (no `YamlMap` in the read path). |
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
| **Cancellation** | **Reuse** `tom_basics` | `TomCancellationToken` / `TomCancellationSource` / `TomOperationCancelled` from `package:tom_basics/utilities.dart`; `agent_send.dart` takes the token. |
| **Content hash** | **Reuse** `tom_basics` | `promptSha256` is `'sha256:'` + `tomSha256OfText`. |
| **Config read** | **Own** (no equivalent) | No YAML config loader/reader exists in `tom_basics` or `tom_core_kernel`. `loadYamlAsMap` + `YamlConfigReader`/`MapFieldReader` own the read path (plain maps, no `YamlMap` leak). |
| **Config write** | **Reuse** `tom_basics` | `TomYamlConfigWriter` is the AST-preserving writer (surgical `set`/`remove` over `yaml_edit`). |

**Audit result:** no divergent re-implementation
of a `tom_core_kernel`-owned primitive was found. Logging, cancellation,
the content hash and the config writer are reused from `tom_basics`;
the clock and the config reader have no `tom_core_*` equivalent; the shutdown
coordinator is a deliberate lightweight-tier alternative to the kernel's
`dart:io`-coupled `TomShutdownCleanup`. The audited helpers
(`CategoryLog`, `systemClock`, `AsyncShutdownCoordinator`,
`YamlConfigReader`/`MapFieldReader`) keep their
existing unit tests.

## Module documentation

One prose page per module with a surface worth explaining, under
[`doc/`](doc/):

| Page | Covers |
| ---- | ------ |
| [`doc/agent.md`](doc/agent.md) | The editor-facing agent session: the eleven YAML sidecars and how a damaged one degrades, bridge discovery and binding, the reconnect back-off, and the send engine's retry and cancellation rules |
| [`doc/api/api_summary_agent.md`](doc/api/api_summary_agent.md) | The symbol-level mirror of the same unit: every exported type, top-level function and constant with a section, held complete by `test/api_summary_test.dart` |
| [`doc/bearer_auth.md`](doc/bearer_auth.md) | The transport-neutral bearer-token contract and its three failure reasons |
| [`doc/mcp_auth.md`](doc/mcp_auth.md) | The MCP-specific `_meta` slot and JSON-RPC refusal code over that contract |
| [`doc/llm.md`](doc/llm.md) | The Agent SDK provider over the `tom_core_llm` contract: its control inversion and single retry, and the three session strategies |
| [`doc/api/api_summary_llm.md`](doc/api/api_summary_llm.md) | The symbol-level mirror of the same unit: six types with a section each and the session-error matcher |
| [`doc/isolate_streaming.md`](doc/isolate_streaming.md) | Streaming results back across an isolate boundary |
| [`doc/api/api_summary_isolate_streaming.md`](doc/api/api_summary_isolate_streaming.md) | The symbol-level mirror of the same unit: twelve types with a section each, and which side of the boundary each lives on |
| [`doc/placeholders.md`](doc/placeholders.md) | The placeholder engine: forms, scope stack, recursion and typed failures |
| [`doc/api/api_summary_placeholders.md`](doc/api/api_summary_placeholders.md) | The symbol-level mirror of the same unit: six types, one function and three constants with a section each, and the wire codes each failure carries |
| [`doc/api/api_summary_index.md`](doc/api/api_summary_index.md) | Which units get a symbol-level summary and which are mirrored by their prose page instead — the ten-type threshold, and the six units measured against it |

## Runnable examples

Six programs under [`example/`](example/), one per module that has a surface
worth driving directly:

| Example | Demonstrates |
| ------- | ------------ |
| [`example/llm/`](example/llm/llm_example.dart) | The provider seam from the implementer's side: a complete `EchoProvider`, the event contract and the route stamp asserted under a model override, and the two shapes one failure takes through `complete` and `run` |
| [`example/agent/`](example/agent/agent_example.dart) | The agent unit end to end without a network: a sidecar round-trip and its two degradation rules, bridge discovery and endpoint matching, the reconnect back-off resolving all three ways, and a send that refreshes a stale session |
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
