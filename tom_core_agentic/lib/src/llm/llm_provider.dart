// LlmProvider — the contract every LLM backend implements.
//
// Migrated into `tom_core_agentic` from the tom_brain substrate provider layer
// (originally `tom_brain_substrate/lib/src/llm/llm_provider.dart`). A single
// abstract class — not a typedef — so the analyzer enforces method-set
// completeness on implementers and a `Map<String, LlmProvider>` keyed by [id]
// stays type-precise.

import 'llm_call_report.dart' show LlmCallReport;
import 'llm_options.dart' show LlmOptions;
import 'llm_stream_event.dart' show LlmStreamEvent;
import 'wire_prompt.dart';

/// One LLM backend a caller can route a call to.
///
/// Implemented by the Anthropic-Agent-SDK provider ([AgentSdkLlmProvider]) and,
/// in the brain, by HTTP and stub providers. Every provider is identified by
/// [id] and held in a caller-owned provider map keyed by it.
///
/// **Anchor invariant.** Every [complete] / [completeStream] implementation
/// MUST stamp the prompt's [WirePrompt.anchorHash] onto the resulting
/// [LlmCallReport.anchorHash]. A provider that drops the hash is a defect.
///
/// **No prompt mutation.** Providers MUST NOT prepend, append, or reorder the
/// body of the prompt they receive. The producer has already wrapped the body
/// with the anchor; any mutation here would corrupt the anchor block or inject
/// text the audit trail cannot attribute. Providers translate
/// [WirePrompt.combined] into whatever wire shape the backend expects, but the
/// body content goes through unchanged.
abstract class LlmProvider {
  /// Stable identifier for this provider instance.
  ///
  /// Used as the key into a caller's provider map and as the `providerId` field
  /// on [LlmCallReport]. Two providers with the same [id] in the same map is a
  /// config error.
  String get id;

  /// Runs the prompt to completion and returns the report.
  ///
  /// Implementations buffer the underlying response into a single
  /// [LlmCallReport]. Both [complete] and [completeStream] are first-class —
  /// neither needs to be implemented in terms of the other.
  ///
  /// Failure shape: providers surface backend failures as exceptions; the
  /// caller classifies them.
  ///
  /// **Anchor stamp.** The returned report's [LlmCallReport.anchorHash] MUST
  /// equal [prompt].[WirePrompt.anchorHash].
  ///
  /// **Provenance stamp.** The returned report's `providerId` MUST equal [id];
  /// the `modelId` MUST equal the resolved model id; the `promptHash` MUST be
  /// the content hash of [prompt].[WirePrompt.combined].
  Future<LlmCallReport> complete(WirePrompt prompt, LlmOptions options);

  /// Streams the prompt's completion.
  ///
  /// Returned stream lifecycle:
  ///
  ///   1. Exactly one [LlmStreamStarted] is emitted first.
  ///   2. Zero or more [LlmStreamChunk] events follow, in order.
  ///   3. Zero or more [LlmStreamToolCallProposed] events may be interleaved.
  ///   4. The stream terminates with exactly one of [LlmStreamCompleted] or
  ///      [LlmStreamFailed].
  ///
  /// **Non-streaming backends** MUST still implement [completeStream] by
  /// buffering the final response and emitting it as a single [LlmStreamChunk]
  /// followed by [LlmStreamCompleted].
  ///
  /// **Anchor + provenance.** Same invariants as [complete]: the terminal
  /// report MUST carry the prompt's anchor hash, this provider's [id], the
  /// resolved model id, and the prompt body hash.
  Stream<LlmStreamEvent> completeStream(WirePrompt prompt, LlmOptions options);
}
