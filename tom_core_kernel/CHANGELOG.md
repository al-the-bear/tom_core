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
