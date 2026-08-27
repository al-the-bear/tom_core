## 1.8.0

### Fixed

- **`agent/bridge_connection.dart`**: `BridgeChoiceStore.load()` had no `try`
  at all — alone among the ten sidecar stores. An unreadable file raised
  `FileSystemException` and a syntactically damaged one raised
  `YamlException`, so a hand-edited sidecar crashed the editor on launch
  instead of costing a re-pick. It now degrades like its nine siblings
  (`FileSystemException` / `FormatException` → `null`) and reads through the
  shared `decodeAgentYaml`, which makes the root-shape check the same one
  they make.
- **`agent/bridge_connection.dart`**: `BridgeChoice.fromMap` cast rather than
  type-tested, so a mis-typed value — `port: "19900"`, the classic hand-edit
  slip — threw a `TypeError` straight past the store's catch. It now defaults
  an unusable value exactly as it already defaulted an absent one. Coverage
  for both defects: `test/bridge_connection_test.dart`.

## 1.7.0

### Features

- **`agent/`**: added the editor-facing agent data models for the TomSpecs
  editor (`tom_specs_editor_specification.md` §20 step 2) — `AgentProfile`
  (incl. the editor-specific `interruptRetryPrefix`, N10), the prompt-queue
  model (`QueuedPrompt` / `QueuedPrePrompt` / `QueuedFollowUpPrompt` with
  statuses, repeats, reminders and multi-transport routing), the chat / trail
  model (`ChatMessage` / `TrailPair`), `ReminderTemplate` and `TimedRequest`.
  All models round-trip through YAML via the new `encodeAgentYaml` /
  `decodeAgentYaml` codec.
- **`agent/`**: added `EditorPlaceholderBindings`, a sync + lenient binder over
  the shared `PlaceholderResolver` that supports `${name}`, `${name?}`,
  `${env:NAME}` and the `{{name}}` alias, and **rejects** the `${{ … }}`
  expression form with `PlaceholderExpressionsUnsupportedError` rather than
  executing it (§11.5, no JS). Coverage: `test/agent_models_test.dart`.

## 1.6.0

### Features

- **`llm/`**: migrated the LLM provider contract (`LlmProvider`, `WirePrompt`,
  `LlmOptions`, `LlmCallReport`, `CapturedWirePrompt`, the `LlmStreamEvent`
  family, `LlmFailure`) and the Anthropic Agent-SDK provider path
  (`AgentSdkLlmProvider`, the `AgentSdkSession*` strategies / store,
  `agentSdkLooksLikeSessionError`) out of the `tom_brain` substrate / run
  layers so the provider seam is reusable outside the brain (the TomSpecs
  editor consumes it over the VS Code bridge). Added the
  `tom_vscode_scripting_api` dependency. The substrate-coupled HTTP / stub
  providers are intentionally not migrated (see the quest's
  `completion_steps.tom_specs.md`, CS-04). Coverage:
  `test/agent_sdk_provider_test.dart`, `test/agent_sdk_session_test.dart`.

## 1.5.0

### Documentation

- **`isolate_streaming/`**: added `doc/isolate_streaming.md` (a module guide for
  the cancellation family, the per-stream close signal, the backpressure ledger,
  the request guard, and the exception registry) and a runnable
  `example/isolate_streaming/isolate_streaming_example.dart`. Filled the one
  remaining dartdoc gap (`IsolateStreamCloseSignal.closeRequested`). No public
  API change; the existing isolate-streaming test files remain the coverage.
- **`mcp_auth/`**: added `doc/mcp_auth.md` (the bearer-token wire contract, the
  authenticator interface, the closed failure taxonomy, and the tier boundary)
  and a runnable `example/mcp_auth/mcp_auth_example.dart` that plays both sides
  of an MCP `initialize` handshake. No public API change; the existing
  `mcp_auth_test.dart` remains the coverage.
- **`placeholders/`**: added `doc/placeholders.md` (the four placeholder forms,
  `resolve`/`resolveSync`, the lexical scope stack, the `${{ … }}` expression
  seam, strict/lenient + recursion policy, and the typed failures) and a runnable
  `example/placeholders/placeholders_example.dart`. No public API change; the
  existing `placeholder_resolver_test.dart` / `placeholder_stack_test.dart`
  remain the coverage. Flagged (for a follow-up) that `PlaceholderResolver` is
  the package's sole `dart:io` import, at odds with the `dart:io`-free design.

## 1.4.0

Consolidated record of the incremental feature development between `1.0.0` and
the current `pubspec.yaml` version `1.4.0`. These primitives were added across
several unversioned increments; the precise per-release (`1.1.0`–`1.3.0`)
boundaries were not recorded at the time, so they are grouped here under the
current package version. Reconstructed from the project's git history.

### Added

- **Isolate-streaming infrastructure** (`isolate_streaming/`): a domain-free
  worker-isolate streaming layer — cooperative `IsolateCancellation`, stream
  close-signalling, a `BackpressureTracker`, a per-request `IsolateRequestGuard`
  (worker-death + per-request deadline), and a generic `IsolateExceptionRegistry`
  that reconstructs typed errors across the isolate boundary.
- **MCP transport-auth contract** (`mcp_auth/`): the generic bearer-auth
  contract and MCP authentication helpers, hosted here so transports share one
  auth abstraction.
- **Placeholder engine** (`placeholders/`): `PlaceholderResolver` as the single
  `${…}` engine, with the expression grammar, a resolution stack, the optional
  `${name?}` form, and the placeholder error types.
- **Generic primitives**: `CategoryLog` (category-tag facade over `tomLog`),
  `systemClock`, `AsyncShutdownCoordinator`, `MapFieldReader`, `YamlConfigWriter`
  (AST-preserving config writes), `promptSha256` (content-hash convention),
  `percentileDuration` / `LatencySummary` (nearest-rank percentile maths),
  `deepValueEquals` / `deepValueHash` (collection equality), SQL helpers
  (`blobFromColumn` / `blobFromColumnOrNull`), JSON helpers (`decodeJsonObject`),
  `formatException`, a `TokenBucket` with snapshot/restore, token-estimate and
  `TtlCache` utilities, a Kahn topological plan ordering, a domain-free procedure
  re-rank scorer, a deliberation-cue classifier, a multi-format tool-call text
  parser, and the `PathScope` / `Deadline` / day-boundary / argument-guard
  sandbox primitives.

## 1.0.0

- Initial version. Generic agentic building blocks extracted from
  `tom_brain_substrate`: `CancellationToken` / `CancellationTokenSource`,
  `OperationCancelled`, `CloseGuard`, `buildUniqueById`, `textPreview`,
  `HttpDate`, and `YamlConfigReader`.
