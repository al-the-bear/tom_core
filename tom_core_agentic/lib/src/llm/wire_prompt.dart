// WirePrompt — the post-assembly, post-anchor-injection prompt a provider sees.
//
// Migrated into `tom_core_agentic` from the tom_brain substrate provider layer
// (originally `tom_brain_substrate/lib/src/llm/wire_prompt.dart`) so the
// provider contract and the Anthropic-Agent-SDK provider can be reused outside
// the brain (e.g. the TomSpecs editor). The type is the *result* of a prompt
// having been assembled and anchored: a two-channel body plus the registry hash
// that proves an anchor block leads the system channel.
//
// This file owns neither the anchor-wrapping mechanics (the producer prepends
// the anchor before constructing a `WirePrompt`) nor any role-template type — a
// provider needs only the wire-level vocabulary (body text + anchor hash +
// provenance), which is exactly what this carries.

/// The post-assembly, post-anchor-injection prompt a provider sees.
///
/// Producers assemble the prompt (role framing + inputs), prepend the
/// assistant-dedication anchor to the [system] channel, and construct a
/// `WirePrompt`. Providers ([LlmProvider] implementations) are the only
/// consumers — they translate `WirePrompt` into whatever shape their backend
/// expects (Anthropic / OpenAI / Ollama JSON, a stub's deterministic echo, the
/// Agent SDK's single query string).
///
/// The class is `final` (no subclassing) because every provider must consume
/// the same shape and a subtype here would invite per-provider variants that
/// bypass the anchor guarantee.
///
/// **Two channels.** A `WirePrompt` carries the prompt as two separate parts so
/// providers can route each to its native channel (a top-level `system` field
/// on Anthropic, a `system`-role message on OpenAI / Ollama). A backend with no
/// channel separation — the Agent SDK, whose `query` takes one string — sends
/// [combined] instead:
///   - [system] — the standing framing: the assistant-dedication anchor,
///     the role persona / objective, the structured-output declaration.
///     This is the part the model treats as instructions.
///   - [user] — the call-specific content (the inputs the caller injected
///     for this one prompt). May be empty for system-only roles.
///
/// The native-channel mapping is the provider's responsibility; a provider that
/// has no channel separation reads [combined].
///
/// **Anchor invariant.** Every `WirePrompt` is produced with an anchor block
/// leading the [system] channel:
///   - [system] BEGINS with the anchor block. The anchor leads the *system*
///     channel — the part the model reads as instructions — so the dedication
///     framing is the first thing every backend sees, regardless of how [user]
///     is delivered.
///   - [anchorHash] is the content hash of the anchor block, used by the
///     provider to stamp [LlmCallReport.anchorHash] so a conformance test can
///     prove the anchor was present on every emitted prompt.
final class WirePrompt {
  /// The standing framing channel, anchor-first.
  ///
  /// Guaranteed shape:
  ///
  /// ```
  /// <anchor block (constant)>
  ///
  /// <role-assembled framing (persona + objective + output schema)>
  /// ```
  ///
  /// A provider routes this to its native system channel (Anthropic top-level
  /// `system`, OpenAI / Ollama `system`-role message). The first paragraph is
  /// always the assistant-dedication anchor.
  final String system;

  /// The call-specific content channel — the inputs the caller injected
  /// for this prompt.
  ///
  /// Empty (the default) for system-only roles that carry no per-call
  /// user text. A provider routes this to its native user channel; a
  /// provider with no channel separation appends it after [system] (see
  /// [combined]).
  final String user;

  /// Content hash of the anchor block that was prepended.
  ///
  /// The provider records this on [LlmCallReport.anchorHash] so a conformance
  /// test can assert equality on every emitted report.
  final String anchorHash;

  /// The role id whose template produced this prompt.
  ///
  /// Carried for observability only. Providers do not branch on `roleId`. The
  /// trail records it so an audit can correlate a wire prompt with the role
  /// that emitted it without reading the prompt body.
  final String roleId;

  /// Git sha of the role template file that assembled the body.
  ///
  /// `null` when the producer cannot resolve a sha (e.g. running against an
  /// unstaged template during development). The provider records this on
  /// [LlmCallReport.templateSha]; a `null` here becomes a `null` there, never
  /// silently zeroed or "unknown".
  final String? templateSha;

  const WirePrompt({
    required this.system,
    this.user = '',
    required this.anchorHash,
    required this.roleId,
    this.templateSha,
  });

  /// The two channels joined into one string, with a blank line between
  /// them and empty parts dropped.
  ///
  /// Two consumers, and only the first is a provider's choice:
  ///
  ///   - **A backend with no channel separation sends this.** The Agent SDK's
  ///     `query` takes one string, so the provider hands it `combined`
  ///     unmodified. A backend that *does* have channels routes [system] and
  ///     [user] to them and never sends `combined`. Which of the two a
  ///     provider does is the whole of its native-channel mapping; this getter
  ///     is the answer for backends that have nowhere to map to, not a way
  ///     station on the road to one.
  ///   - **Every provider hashes it.** [LlmProvider.complete] and
  ///     [LlmProvider.completeStream] must stamp the report's `promptHash`
  ///     with the content hash of `combined` whether or not they send it, so
  ///     one prompt fingerprints the same across two routes that put its
  ///     halves in different places.
  ///
  /// The join is therefore part of the hash contract, not a formatting
  /// detail: change the separator, the order, or the rule that drops an empty
  /// part, and every prompt hashes differently from the way it was already
  /// recorded. The three branches are fixed rather than incidental, and the
  /// suite holds them.
  ///
  /// Because [system] leads (and begins with the anchor), `combined` always
  /// begins with the anchor too.
  String get combined {
    if (user.isEmpty) return system;
    if (system.isEmpty) return user;
    return '$system\n\n$user';
  }
}
