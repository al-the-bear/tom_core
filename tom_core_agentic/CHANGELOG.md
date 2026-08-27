## 1.8.0

### Fixed

- **`Kind` columns in `doc/` named things Dart does not declare.** Eight
  Overview rows across `doc/bearer_auth.md` and `doc/placeholders.md` described
  a symbol's *role* in the column that is asked what its *declaration* is:
  `BearerTokenAuthenticator<P>` was `interface` while being an
  `abstract interface class`, `BearerAuthFailure` was `exception` while being a
  plain `class`, and the six placeholder types were `class` / `interface` /
  `exception` while being `final class` and `abstract interface class`. Each
  cell was true as a description and useless as an answer to the question the
  column exists for — may I extend this, or only implement it? — and the two
  restrictive kinds are exactly the ones the informal words cannot express.
  `doc/mcp_auth.md` and `doc/isolate_streaming.md` were checked the same way and
  were already correct.

### Changed

- **Wire key `tomBrainBearerToken` → `tomBearerToken`** (`bearerTokenMetaKey`).
  The value named `tom_brain` — a package this one does not depend on and never
  will — from when the constant lived there, so every future MCP server in the
  framework (a planning server, a procedure server) would have presented its
  token under a key named for someone else's package, in a package whose barrel
  and README both advertise "generic, domain-free building blocks". Of the five
  symbols in the module this is the only one that had to be *renamed* rather
  than re-exported: the other four are Dart symbols a consumer can rename at
  will, whereas the `_meta` key is the single thing a client and a server agree
  on **out of band** — the compiler renames a symbol, only a coordinated
  release renames a wire key, which is why it was done now, before publication,
  rather than left. Every Dart consumer reads the constant rather than the
  literal, so the compiler carried the rename; the only edits were prose and two
  test expectations. Downstream: `tom_brain_memory`'s MCP server and its
  `a76_bearer_auth_test.dart` were swept in the same pass — its full suite
  (1496 tests, including a two-OS-process client/server run over HTTP) is green,
  so the rename is verified end-to-end on the wire and not merely
  compile-clean. Coverage: `test/mcp_auth_test.dart` gains a case asserting the
  key is scoped to the framework and names no package in it, pinning the
  invariant the rename restored so it cannot quietly regress (513 → 514).
- **`mcp_auth/` → `bearer_auth/` + `mcp_auth/`**: the bearer-auth module was one
  file holding two unrelated things — a transport-neutral failure taxonomy
  (`BearerTokenAuthenticator<P>`, `BearerAuthFailure`,
  `BearerAuthFailureReason`) and two MCP wire constants (`bearerTokenMetaKey`,
  `bearerAuthRpcErrorCode`) — and three documents claimed its existence was what
  stopped servers re-deriving that taxonomy. The claim was false: the HTTP edge
  in `tom_brain_access` declares its own copy with a byte-identical `toString`,
  and does so *while already depending on `tom_core_agentic`*, so availability
  was never the obstacle — reaching the taxonomy meant importing a `_meta` key
  and a JSON-RPC error code an HTTP edge has no use for. The three neutral types
  now live in `lib/src/bearer_auth/`, whose contract file has no imports at all;
  `mcp_auth/` keeps only the two constants and imports the contract, so the
  dependency runs MCP → taxonomy and not back. Their dartdoc was de-MCP-ified in
  the move (the prose described the `initialize` handshake as the only place a
  token could arrive, and `BearerAuthFailure` cross-referenced
  `bearerAuthRpcErrorCode` as *the* translation rather than one edge's mapping)
  — moving the file without that would have carried the coupling along in the
  one form a compiler cannot check. **No call site changes**: all five symbols
  are still exported from the package barrel under the same names with the same
  values and behaviour. Coverage: the six taxonomy tests moved verbatim to
  `test/bearer_auth_test.dart`, which imports
  `src/bearer_auth/bearer_auth_contract.dart` rather than the barrel — so the
  separation is a compile-time fact and folding the types back in beside the
  constants would stop that file compiling. `doc/mcp_auth.md` split accordingly,
  gaining `doc/bearer_auth.md`.

### Fixed

- **`llm/`**: the `llm` unit's flagship worked example — the `EchoProvider` a
  reader copies to write their own provider — broke both of the contracts the
  prose around it is about. It announced `LlmStreamStarted(providerId: 'echo',
  modelId: 'echo')` from a `const` constructor while completing with
  `providerId: id, modelId: options.model ?? 'echo'`, so
  `EchoProvider('primary')` under `LlmOptions(model: 'sonnet')` opened on one
  route and terminated on another; the `const` is what forced it, since a const
  constructor cannot read either value, making the mistake structural rather
  than a typo. Its `complete()` was
  `completeStream(...).whereType<LlmStreamCompleted>().first`, which on a
  failed stream raises a bare `StateError: No element` and discards the
  `LlmStreamFailed` carrying the reason — every failure reported identically
  and uninformatively. The example now stamps `id`/`modelId` on Started and
  drains the stream, rethrowing `failure.cause` or the failure message, which
  is the shape the shipped provider already had. Root cause: the invariant was
  real and tested but stated nowhere a copier would read it —
  `LlmProvider.completeStream` and `LlmStreamStarted`'s field dartdoc only ever
  constrained the *terminal report*, so nothing said Started had to agree with
  it. Both now say so. Coverage: the two tests that touched Started asserted
  its fields against literals that happened to match the report's, which pins
  two values but not the relationship between them; they now assert the
  agreement directly, so a provider that hardcoded the pair fails instead of
  passing.

- **`llm/`**: four documents promised that a provider emits only
  `classCode: 'unknown'`, which the one shipped provider has never done — a
  stream that ends without a terminal result yields `'format'`. The promise was
  the thing a consumer would most reasonably rely on ("I only ever have to
  handle `unknown` from this layer"), and it was false at the single place it
  could be checked, so a consumer switching on `classCode` mishandled exactly
  the malformed-stream case. Resolved by correcting the documents rather than
  narrowing the provider: `format` already appears in the dartdoc's own
  taxonomy list, it is asserted by a test, and flattening it to `unknown` would
  discard the one thing the provider genuinely observed for itself. The four
  now state the actual contract — a provider settles the two classes it can
  determine without interpreting the backend (`format` for a malformed stream,
  `unknown` for everything else) and leaves the rest of the taxonomy to the
  caller, so a consumer must handle both. The same paragraphs called `classCode`
  "kebab-case" in three places while every example listed, and the two values
  actually emitted, are snake_case; nothing in the module is kebab-case.
  Coverage: the two paths that emit `unknown` had tests asserting `message` and
  the report but never `classCode`, which is why the claim could drift
  unnoticed — both now pin it, so all three emission sites are held.

- **`llm/`**: `AgentSdkLlmProvider` misreported both retry fields of every
  `LlmCallReport`. `_buildReport` hardcoded `retries: 0` — including on the
  report emitted *after* the evict-and-retry-fresh path had just burned a
  retry — and `wallClockMs` preferred the SDK result's `duration_ms` over the
  provider's own stopwatch. The two defects compound: `duration_ms` times a
  single attempt on the backend, so on a retried call it silently dropped the
  failed first attempt and the wait between them, which is exactly the case the
  retry counter was supposed to flag. The contract on `LlmCallReport` was right
  all along ("in-caller retries burned before this report", "total wall-clock
  between submission and completion (includes retry waits)"); only the provider
  disagreed. This reached further than the trail: `LlmRouter._foldRetries`
  computes `report.retries + retries`, so the hardcoded zero under-counted the
  router's aggregate too. The provider's retry flag is now an `int retries`
  that `_buildReport` takes as a required argument — required rather than
  defaulted, because a default is what let every report claim a first-shot
  success — and `wallClockMs` always reads the stopwatch, which is started once
  at submission and deliberately read without stopping it, since the
  costed-error branch may still continue into a retry. The agent-SDK provider
  is the only provider affected: the HTTP and stub providers hardcode `0`
  correctly, having no internal retry (the router owns retry for them).
  Coverage: the existing evict-and-retry test now scripts a delay into both
  attempts and asserts `retries: 1` plus a wall clock spanning both, and the
  first-shot test pins `retries: 0`. One existing assertion had to be corrected
  rather than kept — `agent_sdk_provider_test.dart` asserted
  `wallClockMs == 1234`, the scripted `duration_ms`, so it was pinning the
  defect in place; it now asserts the figure is a real elapsed measurement and
  specifically not the backend number.

- **`llm/`**: `AgentSdkSessionStore` honoured its no-throw contract on reads
  only. `_load` degraded a missing, corrupt or unreadable file to an empty map,
  but `_flush` caught nothing — and the provider awaits it twice on paths where
  an exception destroys work already done. `put` runs on the **success** path,
  immediately before the terminal event, so an unwritable store turned a
  completed, billed model call into a stream error: no `LlmStreamCompleted`, no
  report, no usage or cost, and `complete()` throwing too. `remove` runs from
  the evict-and-retry-fresh decision, which the provider awaits *outside* its
  try/catch, so the same store turned a classified `LlmStreamFailed` into an
  unhandled stream error. `_flush` now degrades exactly as `_load` does. The
  guard went into the store rather than into the provider's call ordering
  because that is where the contract is stated, and because it covers both call
  sites: making `record` fire-and-forget would have left the evict path open and
  converted the throw into an unhandled async error. Little is actually lost —
  both mutators update the in-memory cache before flushing, so the session
  survives in-process and only a restart pays the one fresh call the contract
  allows for. Coverage: four tests driving an unwritable store (a path whose
  parent is an ordinary file, so it reproduces without depending on the uid the
  suite runs as) through `put`, `remove`, a successful call, and the evict path.

- **`isolate_streaming/`**: `doc/isolate_streaming.md` had drifted from the
  module in three places at once, all of them the same failure — the prose was
  written before the module reached its current shape and was not re-read as
  the module moved. The `Kind` column called 8 of its 12 rows something the
  declaration does not say (two `exception` rows for types that are
  `final class ... implements Exception`, and six `class` rows for
  `final class`); the Overview row for `IsolateCancellationRegistry` still
  summarised the unknown-token cancel as "remembers late cancels", the
  pre-fix half of a rule that has two branches; and the Concurrency section
  repeated that same half-truth a third time while asserting the tests use
  hand-held `Completer`s "rather than a real isolate" — which the sendability
  group (a live `SendPort`) and the real-isolate cancellation demo in
  `example/isolate_streaming/` had both already falsified. All corrected
  against the declarations and the tests. The completion mirror in
  `_ai/quests/tom_core/completion/` was accurate throughout and was used as
  the reference; the drift was one-sided. Two of the three defects were found
  by auditing the file rather than from the report, and the reported counts
  were themselves off (8 of 12 rows, not nine).
- **`isolate_streaming/`**: `BackpressureTracker` let the closed flag decide
  whether an argument was valid. `grant` returned on `_closed` *before* its
  `n <= 0` check, so `grant(0)` threw while open and passed in silence once
  closed — the same call answered two ways by state the caller may not know,
  and both documents stated the guard unconditionally. `consume` had no closed
  check at all, so it kept drawing down a ledger nobody was keeping, and could
  raise the over-consume `StateError` against a balance that had stopped
  meaning anything. The two methods disagreed with each other and `grant`
  disagreed with its own documentation. Both now follow one rule: **validate
  the argument, then consult the closed flag.** A nonsensical count is a caller
  bug in either state; a state-dependent effect is skipped once the ledger
  closes. Coverage: four tests beside the existing close test in
  `test/isolate_streaming_test.dart`.
- **`isolate_streaming/`**: neither document said what a *closed* tracker does
  with `consume`, which left the primitive's whole close path unspecified —
  the todo's own note called this the real question, the line move being the
  easy half. Written down now, on the class and in both documents: after
  `close` the ledger stops accounting (`grant`/`consume` no-op, `credits`
  freezes) and only `awaitCredit` reports the closure. Making `consume` throw
  instead was considered and rejected on evidence, not symmetry: a close
  routinely lands mid-iteration, after `awaitCredit` returned and the chunk
  went out but before the trailing `consume`, and in `tom_brain_memory`'s
  producer that throw would land outside its `on StateError` guard and in the
  generic catch — reporting a clean close to the host as a stream error.
  `awaitCredit` stays the single unwind point because it is the only one
  callers already handle.
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
