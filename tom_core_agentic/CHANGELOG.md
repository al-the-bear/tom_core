## 1.8.0

### Fixed

- **`isolate_streaming/`**: `IsolateCancellationRegistry.isCancelled` was
  documented as answering "whether or not it is currently registered", which
  it has not done since the post-close-cancel fix and could not do cheaply.
  `dispose()` removes the entry, so a request that really was cancelled reads
  `false` from the registry a moment later — while its handle, which holds the
  entry directly, still reads `true`. The doc promised the durable reading and
  the code gives the in-flight one, and the difference is a silently wrong
  answer rather than an error. The contract is now the narrow one on both the
  dartdoc and in `doc/isolate_streaming.md`: the registry answers for what it
  currently holds (an in-flight entry, or a remembered pre-open cancel), the
  handle is the durable answer for one request, and callers should prefer the
  handle wherever one is in scope. Making the registry durable instead was
  rejected because it recreates the leak the post-close drop exists to prevent
  — ids are never recycled, so a cancelled-and-closed record can only grow for
  the executor's lifetime. Coverage: `registry isCancelled is scoped to the
  registration window` and `a remembered pre-open cancel is inside the window`
  in `test/isolate_streaming_test.dart`, which assert both sides of the
  divergence; the neighbouring post-close-cancel test now says in a comment
  that its `isFalse` follows from this contract rather than stating one of its
  own.
- **`isolate_streaming/`**: `doc/isolate_streaming.md` and the example
  described the cancellation split backwards — registry on the host, handle
  shipped across to the worker — where the source puts the registry and the
  handle inside the executor's isolate and sends only the token. The guide's
  snippet was not merely differently-worded but unrunnable: the handle holds a
  `Completer`, so the first `SendPort.send` raises `ArgumentError: object is
  unsendable`, with nothing to suggest the document had caused it. The prose
  also contradicted itself within four lines, calling the handle a
  "worker-side view" and then having the host construct it. Both now describe
  the split the source implements, and the cancellation demo spawns a real
  isolate instead of faking the boundary with futures — faking it is what let
  an inverted arrangement look as convincing as the correct one. Two adjacent
  inaccuracies found in the same pass are fixed too: the registry does **not**
  remember every late cancel (an id it has already seen is dropped, or the
  pending set would grow forever), and `IsolateRequestGuard` is host-side.
  Coverage: the new `sendability across an isolate boundary` group in
  `test/isolate_streaming_test.dart` pins which members may cross — the fact
  the whole design rests on, previously asserted nowhere, which is why the
  documents could disagree with the code for so long.
- **`agent/`**: a bound bridge that was up and answering could be reported as
  gone. Four defaults named the bridge host and one disagreed —
  `AgentSettings.bridgeHost` was `'localhost'` where `BridgeServer`,
  `BridgeConnectionService` and `BridgeChoice.fromMap` all said `'127.0.0.1'`
  — and both places that compare a binding to a discovered server compared the
  host *strings*. `localhost` and `127.0.0.1` are one endpoint and two
  strings, so in the package's own default configuration `ReconnectCoordinator`
  resolved `stillGone` for a live bridge (the §6.1 still-gone modal, and no
  auto-resend) and the picker's `isBound` showed the bound window as merely
  `available`. Fixed at both levels: the new `defaultBridgeHost` constant
  supplies every host default so they cannot drift again, and the new
  `BridgeChoice.matches` compares endpoints rather than strings, so a host
  typed by hand into the settings file costs nothing either. Coverage:
  `test/bridge_connection_test.dart`, `test/reconnect_test.dart`, and
  `connection_test.dart` in `tom_forge_agentic` for the picker side.
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
- **`agent/`**: every sidecar store caught `FileSystemException` and
  `FormatException` around its load, which answers a file that will not
  *parse* but not a file that parses into the wrong *shape*. An entry whose
  `id` was absent or non-string — the shape a hand-edit produces when a line
  is deleted — threw a `TypeError` out of `fromYaml`, past both catches and
  into the caller. Entries the file cannot supply are now skipped
  individually, so one damaged row costs that row rather than the whole file.
  The nested lists (`QueuedPrompt.prePrompts` / `.followUps`,
  `TimedRequest.scheduledTimes`, `AgentProfile.enabledTools`,
  `TrailPair.answer`) skip bad elements the same way. Coverage:
  `test/sidecar_shape_damage_test.dart`.

### Changed

- **`agent/timed_request.dart`**: `TimedRequest.scheduleMode` is now a required
  constructor parameter (it defaulted to `ScheduleMode.interval`). The default
  was introduced by the port — the upstream
  `tom_vscode_scripting_api.TimedRequest` requires it — and it meant a request
  built without the parameter became an interval request nobody chose, with
  `intervalMinutes` nullable beside it. Its payload stays optional: these are
  editor working state, and "scheduled, but no times entered yet" is a state
  the type has to be able to hold. The persisted key also stays optional,
  coerced by `ScheduleMode.fromValue`, so a hand-edited file costs a re-pick
  rather than the entry.
- **`agent/agent_sidecar.dart`** (new, exported): `readAgentYamlFile`,
  `decodeAgentYamlList` and `decodeAgentYamlValue` — plus
  `decodeAgentYamlEntries` in `agent/agent_yaml.dart` for the nested lists.
  The ten stores had ten copies of one `load()` body, and the copies had
  drifted exactly as copies do: one shipped with no `try` at all (above), and
  all ten mistook "parses as YAML" for "is shaped like the model". All ten now
  read through this one path, so "every sidecar degrades the same way" is a
  property of one function rather than a claim about ten bodies. No behaviour
  change beyond the fixes above.

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
