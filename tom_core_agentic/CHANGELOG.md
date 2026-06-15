## Unreleased

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
