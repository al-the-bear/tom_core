// LlmCallReport — the provenance record produced when an LLM call completes.
//
// Migrated into `tom_core_agentic` from the tom_brain substrate api/ layer
// (originally part of `tom_brain_substrate/lib/src/api/llm_call.dart`). A pure
// value class with no domain coupling, split out from `LlmOptions` so each
// lives in its own file.

/// Report produced when an LLM call completes (successfully or with a failure
/// the caller could classify).
///
/// Carries enough provenance to attribute every byte of LLM activity:
///
///   - `providerId` / `modelId` — which route served the call.
///   - `anchorHash` — content hash of the anchor block that was prepended.
///     A caller can compare it against the expected anchor hash on every
///     report as structural proof the call carried the anchor.
///   - `promptHash` — content hash of the assembled wire prompt (anchor + role
///     text + inputs). Lets the trail correlate prompts across runs without
///     storing the body.
///   - `tokensIn` / `tokensOut` — when the provider returns usage fields; else
///     0 (the caller may estimate via a tokeniser).
///   - `retries` — how many in-caller retries happened before this report.
///     0 on a first-shot success.
///   - `wallClockMs` — total wall-clock between submission and completion
///     (includes retry waits).
///   - `cost` — `null` when no price is known for `(providerId, modelId)`;
///     never silently zero.
///   - `templateSha` — git sha of the role template that produced the prompt.
///   - `notes` — free-form provider-side notes the caller may attach
///     (e.g. "response_format downgraded to text"). Carried verbatim into the
///     trail.
final class LlmCallReport {
  final String providerId;
  final String modelId;
  final String anchorHash;
  final String promptHash;
  final int tokensIn;
  final int tokensOut;
  final int retries;
  final int wallClockMs;
  final double? cost;
  final String? templateSha;
  final List<String> notes;

  const LlmCallReport({
    required this.providerId,
    required this.modelId,
    required this.anchorHash,
    required this.promptHash,
    required this.tokensIn,
    required this.tokensOut,
    required this.retries,
    required this.wallClockMs,
    this.cost,
    this.templateSha,
    this.notes = const <String>[],
  });
}
