## 1.1.10

### Changed

- **`shutdown_cleanup/` per-module pass (RCK5).** Private-only DRY refactor of
  `tom_shutdown_cleanup.dart` with every public signature frozen. Two genuine,
  behaviour-preserving deduplications:
  - `_executeCleanup` held three near-identical try/catch loops (over
    `_signalHandlers`, `_closables`, `_disposables`) that each isolated one
    callout and printed `Failed to call <noun> $item` when not `silent`. The
    per-entry isolate/report policy is now owned by a single private generic
    `_runPhase<T>(List<T> items, String label, void Function(T) action)`, and
    `_executeCleanup` is three one-line phase calls. A change to the isolation
    or diagnostic policy is now a one-site edit instead of three. The exact log
    wording (`Failed to call signalHandler/closable/disposable $item`) is
    preserved.
  - The constructor's two SIGHUP/SIGINT watcher registrations duplicated the
    exact `_signalSubscriptions.add(sig.watch().listen(_signalHandler))` body of
    `addSignal`; the constructor now calls `addSignal(...)`, so there is a
    single owner of how a signal is watched and how its subscription is retained
    for teardown (bug §53).

### Examples & Tests

- Added `example/shutdown_cleanup/02_shutdown_execution_example.dart`, wired into
  the module runner. The existing `01_*` example is descriptive and never
  actually triggers cleanup; the new example *executes* the runtime API end to
  end — phase order, once-only execution, fault isolation, `paused` (signal path
  skipped / manual path always runs), `silent`, `cancelAll`/`dispose` teardown,
  and `TomCloseAdaptor` resolving a custom-named teardown method via reflection —
  all guarded by `assert`s (run under `--enable-asserts`). Registered as a
  reflection entry point in `build.yaml`.
- Added a `test/shutdown_cleanup_test.dart` case pinning the manual-path
  contract: `performShutdown()` (the non-signal path) ignores `paused`, which
  was previously asserted only for the signal-driven path. Suite: 64 cases.

## 1.1.9

### Changed

- **`settings/` per-module pass (RCK4).** Audit of
  `settings_client_authorization.dart` (two serialization DTOs —
  `TomGetSettingsMessage`, `TomGetSettingsResult`). No genuine within-module
  duplication exists to extract: the classes are independent data holders and
  the constructor's `?? <T>{}` / `?? <T>[]` defaulting is idiomatic per-field
  initialization, not extractable logic. The one honest, signature-preserving
  cleanup: removed the dead `= ""` field initializers on `TomGetSettingsResult`'s
  eight nullable `String?` fields (`organization`, `process`, `application`,
  `country`, `language`, `clientCountry`, `clientLanguage`, `clientTimeZone`).
  Every one is an initializing formal (`this.x`) in the constructor, so the
  field-level `= ""` never took effect — the real default was already `null`
  (as the existing tests assert). The initializer was dead code that misled
  readers about the default; removing it changes no runtime behaviour and no
  public signature. `TomGetSettingsMessage.authorizationToken = ""` is
  deliberately left — it has no initializing formal, so its `= ""` is the live
  default (`''`). Constructor dartdoc corrected ("all string parameters default
  to null"). No consumer relied on a `""` default (verified across samples and
  tom_uam — they only write the fields), so no adaptation was needed.

### Examples & Tests

- No additions needed: `example/settings/01_client_authorization_example.dart`
  (15 scenarios) and `test/settings_test.dart` (72 cases) already cover the full
  public surface of both DTOs, including the null-default guard that pins the
  dead-initializer removal ("should create result with default null optional
  strings") and the reflection JSON round-trip. No reflection regen — field
  types and names unchanged. Suite: 1690 passing.

## 1.1.8

### Changed

- **`context/` per-module pass (RCK3).** Private-only DRY refactor of
  `execution_context.dart` with frozen public signatures. Two genuine
  duplications were extracted: (1) `runInContext` and `runInContextAsync` shared
  a byte-for-byte preamble that built the new `TomExecutionContext` + merged
  `TomZoneValues` and assembled the zone-values map — now a single file-private
  `_buildZoneValues`, so each run method is a one-line `runZoned` call and the
  superfluous `async` (no `await`) was dropped from `runInContextAsync`;
  (2) all nine `TomContextProviders` getters read the current zone's
  `TomPrincipal`, selected one field, and fell back to a default — that
  read-select-fallback now lives once in `_fromPrincipal`, each getter reduced to
  a one-line selector so a change to how the principal is resolved lands in one
  place.

### Examples

- **New `example/context/04_async_and_zonevalues_example.dart`** covering the
  surface examples 01–03 omit: `runInContextAsync` context propagation across an
  `await` boundary and through nested async runs (inherit-outer, inner-wins), and
  the full `TomZoneValues` mutation API (`addAll` chaining, `containsKey`,
  `remove`, `clear`) plus the `existingValues` merge constructor. Wired into
  `00_run_all_examples.dart` (now async); self-asserts under `--enable-asserts`.

### Tests

- Added the five missing principal-populated provider tests (`getProcess`,
  `getCountry`, `getTimezone`, `getClientLanguage`, `getClientCountry`) so each
  of the nine refactored one-line selectors is verified against a live principal,
  guarding against a mis-wired field selector. Suite: 1690 passing.

## 1.1.7

### Changed

- **`resources/` per-module pass (RCK2).** Private-only DRY refactor of
  `tom_resource_provider.dart` with frozen public signatures. Both providers
  resolved a key the same way — a dot-notation tree walk (`getObjectFromTree`)
  then a flat-key fallback — duplicated across eight accessor bodies
  (`TomTextResourceProvider.{exists, existsObject, getObject, getObjectOrNull,
  getText, getTextOrNull}` and `TomConfigResourceProvider.{exists, getText}`).
  That rule now lives once in two file-private helpers: `_resolveObjectOrNull`
  (any value type) backs the object family and `_resolveStringOrNull` (String
  only) backs the text family, each accessor reduced to a one-line expression
  differing solely in its missing-value fallback. The text/object split is kept
  deliberately: the text helper still consults the flat key when the tree walk
  lands on a non-String, so a literal dotted key resolves — a genuine semantic
  difference, not coincidental duplication.

### Examples

- **New `example/resources/03_app_singleton_example.dart`** covering the
  application-wide singleton surface that examples 01/02 omit: the static
  `loader` field, the loader-driven default constructor,
  `getAppResources`/`getAppConfig` lazy initialization, `setAppResourceProvider`/
  `setAppConfigProvider` replacement, singleton identity, and the independence of
  the text and config singletons. Wired into `00_run_all_examples.dart`;
  self-asserts under `--enable-asserts`.

### Tests

- **Added a `shared resolution contract` group to `test/resources_test.dart`**
  (98 → 102) pinning the extracted helpers: the flat-String fallback on a
  non-String tree hit (literal dotted key beside a nested value), object-family
  resolution at a hierarchical path, the object-vs-text divergence on a nested
  non-String, and config/text object-family parity.

## 1.1.6

### Changed

- **`isolate_pooling/` per-module pass (RCK1).** Private-only DRY refactor of
  `tom_worker.dart`: the two identical response-completion bodies (worker→creator
  and creator→worker) are now a single private `_completeFromResponse(completer,
  response)` helper that routes a `RemoteError` payload to `completeError` and any
  other payload to `complete`. Public signatures are unchanged. The stale
  `// TODO: add regular pings` note on `TomWorkerPool` is replaced by an
  explanatory comment; the liveness-supervision enhancement is tracked as quest
  todo **RCJ1**.

### Examples

- **New `example/isolate_pooling/03_creator_backchannel_example.dart`** covering
  the worker→creator back-channel that had zero example coverage:
  `TomWorker.canSendToCreator`, `executeInCreator` (request/response),
  `sendToCreator` (fire-and-forget into a creator-side `TomExecutor`), a custom
  `TomWorkerContext` with `initializeIsolate`/`initializeWorker` overrides, and
  error propagation as a `RemoteError`. Wired into `00_run_all_examples.dart`.
- **Fixed a latent bug** in `02_worker_pool_example.dart`: a missing `await` cast
  a `Future<Object?>` to `bool` and crashed the example under `--enable-asserts`.
  Also removed confusing `Future.value(pool.execute(...))` wrappers in favour of
  the plain `Future`s that `pool.execute` already returns.

### Tests

- **Scaled `test/isolate_pooling_test.dart`** (+5 tests) to the full public API:
  the base `TomCommand.execute` default (`"null"` sentinel), the
  `startRemoteIsolate` null-send-port guard (the last untested documented
  exception key), `canSendToCreator`/`sendToCreator` observed from inside a
  worker, an end-to-end `sendExecutorToIsolate` assertion, and the
  creator-thrown-exception-as-value branch of the shared response-completion
  helper.

## 1.1.5

### Added

- **`TomRemoteLogOutput` delivery resilience (RCI2).** The remote log output now
  never silently drops a record. A send is treated as *failed* both when the
  transport throws **and** when the server answers with an error result
  (`TomServerCallError.hasError`) — the previously `print()`-only returned-error
  path now routes through the fallback like the thrown path. Four new static
  knobs make resilience opt-in and predictable-by-default:
  - `globalSettingMaxSendRetries` (default `0`) — additional attempts after the
    first failure.
  - `globalSettingRetryBackoff` (default `Duration.zero`) — linear backoff; the
    wait before retry *k* is `backoff × k`.
  - `globalSettingReplayQueueMaxSize` (default `0`, disabled) — bounded
    in-memory replay queue; records that exhaust their retries are buffered and
    re-sent oldest-first on the next successful transmission, dropping the
    oldest on overflow.
  - `replayQueueLength` (read-only) and `clearReplayQueue()` — diagnostics and a
    way to discard records queued for a previous endpoint when reconfiguring.

  The defaults preserve the prior single-attempt-then-fallback behaviour, so no
  configuration is required and the path stays testable without a live server.

### Examples

- **Extended `example/logging/04_isolate_and_remote_logging_example.dart`** with
  an Example 9 that drives the resilience surface offline via a scripted
  endpoint: a flaky endpoint recovered by retry, a full outage buffering a
  record, and a recovery that drains the buffer oldest-first before the
  triggering record. Self-asserts under `--enable-asserts`.

### Tests

- **Added a `TomRemoteLogOutput` `resilience` group to `test/logging_test.dart`**
  (kernel suite 1667 → 1676): default knobs; returned-error routed to fallback;
  retry recovers a transient failure and gives up after the budget; backoff
  actually waits between retries; replay queue buffers a failed record and
  drains it in order on the next send, drops the oldest on overflow, and stops
  draining while the endpoint is still down. The `_MockLogEndpoint` test double
  gained a per-call outcome script (`ok` / throw / returned-error) and an
  `accepted` log for asserting drain ordering.

## 1.1.4

### Refactor

- **`http_connection/` per-module pass (RCI1).** Internal DRY refactor with
  frozen public signatures. The six `TomServerCall` response accessors
  (`getResponseHeaders`, `getResponseStatusCode`, `getResponseContentLength`,
  `getResponseIsRedirect`, `getResponseReasonPhrase`, `getResponseRequest`) each
  repeated the same "throw if nothing was sent yet, then await the response"
  guard with only the error key/message differing; extracted that into a private
  `_requireSentResponse(key, message)` helper so every accessor states only its
  own wording. The duplicated read-once guard in `read()`/`readAsString()` moved
  into a private `_ensureNotYetRead(key)` helper. `read()` keeps its original
  `_read = true`-before-await ordering to preserve concurrent-read semantics.

### Examples

- **Added `example/http_connection/04_auth_retry_example.dart`** exercising the
  real framework auth-retry coordinator — `tomRunWithAuthRetry`,
  `TomAuthRefresher`, `TomAuthRetryPolicy` (default, custom, and bean-resolved
  `active`), and `TomAuthExpiredException` — across the happy path, expiry
  recovery, declined refresh, persistent-expiry throw, non-expiry passthrough,
  and a custom multi-retry policy. Wired into `00_run_all_examples.dart` (now
  `async`). This closes the gap left by `03_retry_policies_example.dart`, which
  only demonstrated a hand-rolled pattern, not the kernel API.

### Tests

- **Added auth-retry coverage to `test/http_connection_test.dart`** (previously
  zero tests for `auth_retry.dart`): `TomAuthRetryPolicy` (defaults, custom
  tuning, `active` bean resolution and reset fallback), `TomAuthExpiredException`
  (status/key/message), and `tomRunWithAuthRetry` (no-refresh passthrough,
  one-refresh recovery, declined refresh, persistent-expiry throw with and
  without `errorKeyOf`, non-expiry passthrough, refresher error propagation,
  explicit-policy budget, active-bean policy resolution).

## 1.1.3

### Refactor

- **`logging/` per-module pass (RCH1).** Internal DRY refactor with frozen
  public signatures. `TomIsolateLogOutput.output` and
  `TomCreatorLogOutput.output` built the *identical* `TomInterIsolateLogMessage`
  record before dispatch (only the destination differs — worker pool vs. back
  to the creator); extracted that byte-for-byte construction into a private
  `_interIsolateMessage(...)` helper so the record's shape lives in one place.
  The two `output` bodies stay separate: their dispatch/fallback logic is a
  genuinely different concern, not coincidental duplication. Replaced the stale
  `// TODO: add error handling` note inside `TomRemoteLogOutput.output` with an
  explanatory comment; the resilience enhancement it hinted at (retry-with-
  backoff, bounded replay queue) is filed as **RCI2** in the tom_core quest
  todos rather than attempted inline in a signature-frozen pass.

### Examples

- **Added `example/logging/04_isolate_and_remote_logging_example.dart`** covering
  the kernel-owned isolate/remote logging surface, which previously had no
  runnable example (examples `01`–`03` only exercise the `tom_basics`
  `TomLogger` foundation). It drives — connection-free (zero-size worker pools,
  no configured endpoint) — `TomInterIsolateLogMessage`, `TomLoggingExecutor`,
  `TomIsolateLogOutput` (level gating), `TomCreatorLogOutput` (off-isolate
  fallback + gating), `TomLoggingWorkerContext`/`TomIsolateLogging`,
  `TomRemoteLogMessage`/`TomRemoteLogResult`/`TomLoggingContext`,
  `TomRemoteLogOutput` (no-endpoint fallback), and `TomRemoteLogServer`
  (receive, sender-prefixing, CWE-117 control-character sanitization). Wired
  into `00_run_all_examples.dart` (now async). Self-asserts under
  `dart run --enable-asserts`.

### Tests

- **Closed the `TomLoggingWorkerContext` test gap.** Added a group asserting it
  is a `TomWorkerContext` and that `initializeIsolate()` registers a
  `TomLoggingExecutor` on `TomWorker.executors` and returns `true` (with the
  global executor list snapshotted and restored). Kernel suite 1650 → 1652,
  all green; `dart analyze` clean.

## 1.1.2

### Refactor

- **`security/` per-module pass (RCG1).** Internal DRY refactor with frozen
  public signatures: `TomRoleAccess` and `TomGroupAccess` had byte-for-byte
  identical `checkAccessibility` bodies — extracted the shared rule into a
  private `_principalAciContainsAny` helper (each class supplies its ACI
  collection selector). `TomEntitlementAccess` is deliberately left separate:
  regex matching is a genuinely different rule, not coincidental duplication.

### Examples

- **Added `example/security/04_graded_access_example.dart`** covering the
  four-state `TomGradedAccess` / `TomAuthState` surface, which previously had no
  runnable example: full/read/disabled/none resolution, the `read`→`full` and
  `disabled`→`read` defaulting, `checkAccessibility`'s collapse to
  `showsContent`, the `TomAuthState` predicates, and the binary→four-state
  default bridge. Wired into `00_run_all_examples.dart`. Self-asserts under
  `dart run --enable-asserts`.

### Fixes

- **Fixed a latent stale assertion in `02_access_control_example.dart`.** Its
  Example-6 group assertions documented a since-fixed constructor bug ("groups
  populated from resourceKeys"); the `TomAccessControlInformation` constructor
  now correctly populates `_groups`, so the assertions failed under
  `--enable-asserts`. Corrected them to the real group-membership outcomes and
  removed the obsolete bug note.

### Tests

- **`security_test.dart`** +3 tests pinning the extracted helper's contract
  (empty candidate list denies; Role/Group parity for an empty ACI collection).
  Suite 1647 → 1650, all green (serial).

## 1.1.1

### Documentation

- **Added a per-module API reference under `doc/api_reference/`.** Fifteen
  hand-written summaries — one per barrel-exported `tombase` module
  (`beanlocator`, `context`, `http_connection`, `isolate_pooling`, `json`,
  `little_things`, `logging`, `observable`, `reflection`, `resources`,
  `scope_ids`, `security`, `settings`, `shutdown_cleanup`, `timezoned`) — plus a
  cross-module `api_summary_index.md`. Each summary follows the standard format
  (overview with source paths, class hierarchy, per-class constructors and
  static/instance members, enums, top-level functions/constants; public members
  only). Verified against the actual public declarations and the package barrel.
  This restores documentation symmetry with `tom_core_server`,
  `tom_core_flutter`, and `tom_core_d4rt`, which already carry `doc/api_reference/`
  sets, and linked the reference from the README. No source or behaviour change.

## 1.1.0

### Added

- **Scope IDs module** (`scope_ids`): hierarchical, zone-propagated `TomScope`
  identifiers (`TomScope`, `TomScopeBase`, `TomScopeMixin`) for namespacing
  resource and authorization lookups, plus `InScopeBuilder` for restoring a
  captured scope inside deferred framework callbacks.
- **UI authorization** (`security/tom_authorization.dart`): the four-state
  `TomAuthState` model with `narrow`/`widen` algebra, `TomAuthorizable`,
  `TomAuthorizationGroup` (with `AuthGroupMode`), the global `TomAuthorization`
  singleton and `TomAuthorizationAdapter`, `TomAuthorizer` (with
  `TomAuthorizerStrategy`), and `TomUIStateController`.
- **Observable**: `TomList.resetWith` for atomic batch replacement with a single
  notification, and `TomListLifecycleListener` (`onBeforeClear` / `onAfterReset`)
  for tearing down and recreating element-tied state around a reset.
- **Resources**: null-returning and object accessors on
  `TomTextResourceProvider` — `getTextOrNull`, `getObject`, `getObjectOrNull`,
  and `existsObject`.

### Changed

- Observable notification now snapshots its listener/observer lists before
  iterating, guarding against concurrent modification when a callback mutates
  the list during a reset.

### Documentation

- Customized the package README and updated module docs, executable examples,
  and tests for the modules above.

## 1.0.0

- Initial version.
