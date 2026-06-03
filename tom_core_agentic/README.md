# tom_core_agentic

Generic, domain-free building blocks for agentic systems in the TOM
framework. Everything here depends only on `tom_basics` (plus `yaml`
for the config reader) and is safe to reuse across the brain, the
assistant, and any future agent runtime.

## What lives here

| Building block | Purpose |
|----------------|---------|
| `CancellationToken` / `CancellationTokenSource` | Cooperative cancellation for long-running async work. |
| `OperationCancelled` | Public exception thrown when a cancelled token is observed. |
| `CloseGuard` | Mixin that tracks a `isClosed` flag and throws on use-after-close. |
| `buildUniqueById` | Build an id-keyed map from a list, rejecting duplicate ids. |
| `textPreview` | Single-line, length-bounded preview of arbitrary text. |
| `HttpDate` | RFC 7231 / RFC 1123 HTTP-date parsing and formatting. |
| `YamlConfigReader` | Typed, dotted-path reads over parsed YAML with `${ENV}` expansion. |

## What does NOT live here

Anything brain- or domain-specific. The `sha256:<hex>` prompt-hash
convention and the `BrainEventBus<E>` live in `tom_brain_shared`;
retry / circuit-breaker transport policy lives in `tom_core_kernel`.
