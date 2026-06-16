// LlmStreamEvent — the sealed sum of events emitted from a streamed completion.
//
// Migrated into `tom_core_agentic` from the tom_brain substrate api/ layer
// (originally `tom_brain_substrate/lib/src/api/llm_stream_event.dart`). The five
// variants are the closed set of things that can come out of
// [LlmProvider.completeStream]; consumers pattern-match with `switch` and the
// analyzer enforces exhaustiveness. Errors are carried as a typed [LlmFailure]
// envelope (class code + message) — classification is the caller's job, not
// this file's.

import 'captured_wire.dart';
import 'llm_call_report.dart';

/// Events emitted on a `Stream<LlmStreamEvent>` from
/// [LlmProvider.completeStream].
///
/// Lifecycle:
///   - Exactly one [LlmStreamStarted] is emitted first.
///   - Zero or more [LlmStreamChunk] events follow, in order.
///   - Zero or more [LlmStreamToolCallProposed] events may be interleaved with
///     chunks; the provider pauses the stream after a tool-call until the
///     caller resolves it.
///   - The stream terminates with **exactly one** of [LlmStreamCompleted] or
///     [LlmStreamFailed].
sealed class LlmStreamEvent {
  const LlmStreamEvent();
}

/// First event on every stream. Carries the call id assigned by the caller so
/// consumers can correlate subsequent chunks with the originating call.
final class LlmStreamStarted extends LlmStreamEvent {
  /// Opaque identifier for this call. Matches the `callId` field of
  /// [LlmStreamCompleted] / [LlmStreamFailed].
  final String callId;

  /// Provider that was selected for this call.
  final String providerId;

  /// Model id within the provider.
  final String modelId;

  const LlmStreamStarted({
    required this.callId,
    required this.providerId,
    required this.modelId,
  });
}

/// One chunk of streamed text. Chunks may arrive in any granularity the
/// provider chooses; consumers concatenate the [text] fields to reconstruct the
/// full response.
final class LlmStreamChunk extends LlmStreamEvent {
  final String callId;
  final String text;

  const LlmStreamChunk({required this.callId, required this.text});
}

/// The provider proposed a tool call. The stream is paused while the caller
/// resolves the call; resumption happens when the caller posts the tool result
/// back.
///
/// `arguments` is the JSON-shaped argument object the provider emitted,
/// validated against the tool's `parametersSchema`. Validation failures surface
/// as a [LlmStreamFailed] event.
final class LlmStreamToolCallProposed extends LlmStreamEvent {
  final String callId;

  /// Provider-side tool-call id. Used by the caller to post the resolution
  /// back; not interpreted here.
  final String toolCallId;

  /// The tool's canonical name (matches a [ToolDescriptor.name] in the call's
  /// [ToolCatalogue]).
  final String toolName;

  /// Argument object, JSON-shaped.
  final Map<String, Object?> arguments;

  const LlmStreamToolCallProposed({
    required this.callId,
    required this.toolCallId,
    required this.toolName,
    required this.arguments,
  });
}

/// Successful completion. Carries the final [LlmCallReport] so the caller does
/// not need to await a separate future after the stream closes.
final class LlmStreamCompleted extends LlmStreamEvent {
  final String callId;
  final LlmCallReport report;

  /// The wire body the provider actually saw, when the producing layer attached
  /// it. `null` when the event originates below a facade that has no
  /// role-assembled wire to attach.
  final CapturedWirePrompt? wire;

  const LlmStreamCompleted({
    required this.callId,
    required this.report,
    this.wire,
  });
}

/// Terminal failure. Carries both the typed failure (so the caller can branch
/// on the failure class) and a best-effort [LlmCallReport] reflecting what was
/// known at the point of failure (tokens streamed so far, wall-clock spent,
/// retries already burned).
final class LlmStreamFailed extends LlmStreamEvent {
  final String callId;
  final LlmFailure failure;
  final LlmCallReport report;

  const LlmStreamFailed({
    required this.callId,
    required this.failure,
    required this.report,
  });
}

/// Typed failure envelope.
///
/// [classCode] is a stable kebab-case discriminator (e.g. `rate_limit`,
/// `overloaded`, `billing`, `timeout`, `auth`, `auth_permanent`,
/// `model_not_found`, `context_overflow`, `format`, `network`,
/// `cancelled_by_consumer`, `unknown`). Providers emit `unknown` and leave the
/// mapping onto the taxonomy to the caller; consumers that just need to log or
/// surface the failure use [message].
final class LlmFailure {
  /// Stable kebab-case discriminator.
  final String classCode;

  /// Human-readable diagnostic. Not for end-user display; for logger / trail
  /// entries.
  final String message;

  /// Optional underlying error. Carried for debugging only — consumers should
  /// not pattern-match on its runtime type.
  final Object? cause;

  const LlmFailure({
    required this.classCode,
    required this.message,
    this.cause,
  });
}
