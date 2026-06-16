// LlmOptions, ToolCatalogue, ToolDescriptor — the per-call knobs and tool
// vocabulary of an LLM call.
//
// Migrated into `tom_core_agentic` from the tom_brain substrate api/ layer
// (originally the provider-facing half of `tom_brain_substrate/lib/src/api/
// llm_call.dart`). The substrate's `LlmCall` (which couples to brain-specific
// `Budget` / `TurnId` / route types) is deliberately left behind: providers and
// the Agent SDK path need only these provider-facing value types, so splitting
// them out keeps `tom_core_agentic` free of any brain-domain dependency.

/// Per-call provider-tunable knobs.
///
/// Every field is optional. A caller resolves unset fields against its own
/// defaults. Providers that do not support a given knob downgrade gracefully
/// and may append a note to [LlmCallReport.notes]; a call is not failed just
/// because a knob did not apply.
final class LlmOptions {
  /// Optional override of the route-resolved model id.
  ///
  /// When non-null the caller uses it verbatim, subject to availability on the
  /// selected provider; when null the provider's route default applies. The
  /// resolved model id is stamped onto [LlmCallReport.modelId] for trail
  /// attribution regardless of which step produced it.
  ///
  /// Stored as `String?` (not a stronger `ModelId` type) because model ids are
  /// configured, not enumerated in code.
  final String? model;

  /// Sampling temperature in `[0.0, 2.0]`. `null` ⇒ provider / role default.
  final double? temperature;

  /// Hard cap on the response token count. `null` ⇒ provider / role default.
  ///
  /// The field keeps the fuller name `maxOutputTokens` because every prototype
  /// provider (Ollama `/api/chat`'s `num_predict`, OpenAI `max_tokens`) applies
  /// the cap to output only.
  final int? maxOutputTokens;

  /// Generation halts when any of these strings appears in the emitted text.
  /// Always treated as an unordered set (the provider may reorder for prefix
  /// matching).
  ///
  /// Defaults to `const <String>[]` (no stop sequences). The constructor makes
  /// it non-nullable with an empty-list default rather than accepting `null`,
  /// so a caller cannot defeat the const default by passing `null`.
  final List<String> stopSequences;

  /// Tools the role is allowed to call during this completion.
  /// Empty ⇒ no tool calls permitted. A provider that surfaces tool calls
  /// emits [LlmStreamToolCallProposed] events and waits for the caller's
  /// tool-call adapter to resolve them.
  final ToolCatalogue toolCatalogue;

  /// Optional structured-response declaration. Currently a JSON schema as a
  /// `Map<String, Object?>`. `null` ⇒ free-form text response.
  final Map<String, Object?>? responseFormat;

  /// The live session id this call belongs to, stamped by the caller for
  /// user-turn calls; `null` for background paths that run outside a session.
  ///
  /// Every HTTP / stub provider **ignores** it — it exists solely so the
  /// [AgentSdkLlmProvider] in its `sessionMode: brain` can key the persisted
  /// Claude-Code session id by the originating session. Threading it here, as
  /// one optional field, keeps the seam small and costs nothing for every
  /// provider that does not read it.
  final String? brainSessionId;

  const LlmOptions({
    this.model,
    this.temperature,
    this.maxOutputTokens,
    this.stopSequences = const <String>[],
    this.toolCatalogue = ToolCatalogue.empty,
    this.responseFormat,
    this.brainSessionId,
  });

  /// The all-defaults instance. Consumers that need to tweak one field build a
  /// new instance.
  static const LlmOptions empty = LlmOptions();

  /// Returns a copy of this instance with selected fields replaced.
  ///
  /// Passing `null` for [model], [temperature], [maxOutputTokens],
  /// [responseFormat], or [brainSessionId] explicitly clears the field (sets
  /// it to null), while omitting the parameter leaves the existing value
  /// untouched. The private `_unset` sentinel distinguishes the two.
  LlmOptions copyWith({
    Object? model = _unset,
    Object? temperature = _unset,
    Object? maxOutputTokens = _unset,
    List<String>? stopSequences,
    ToolCatalogue? toolCatalogue,
    Object? responseFormat = _unset,
    Object? brainSessionId = _unset,
  }) {
    return LlmOptions(
      model: identical(model, _unset) ? this.model : model as String?,
      temperature: identical(temperature, _unset)
          ? this.temperature
          : temperature as double?,
      maxOutputTokens: identical(maxOutputTokens, _unset)
          ? this.maxOutputTokens
          : maxOutputTokens as int?,
      stopSequences: stopSequences ?? this.stopSequences,
      toolCatalogue: toolCatalogue ?? this.toolCatalogue,
      responseFormat: identical(responseFormat, _unset)
          ? this.responseFormat
          : responseFormat as Map<String, Object?>?,
      brainSessionId: identical(brainSessionId, _unset)
          ? this.brainSessionId
          : brainSessionId as String?,
    );
  }

  /// Private sentinel used by [copyWith] to distinguish "omit" from
  /// "explicitly set to null" on nullable fields. Not exported.
  static const Object _unset = Object();
}

/// The catalogue of tools a role may invoke during a completion.
///
/// A separate type rather than a `List<ToolDescriptor>` so the caller can later
/// attach catalogue-level metadata (provenance hash, supported-by-provider
/// matrix, etc.) without churning every call site.
final class ToolCatalogue {
  /// The tools available, in declaration order. Provider adapters translate
  /// these into provider-native tool schemas.
  final List<ToolDescriptor> tools;

  const ToolCatalogue(this.tools);

  /// The catalogue with zero tools. Use this when the role is not allowed to
  /// invoke any tool during the completion.
  static const ToolCatalogue empty = ToolCatalogue(<ToolDescriptor>[]);

  bool get isEmpty => tools.isEmpty;
  bool get isNotEmpty => tools.isNotEmpty;
}

/// One tool the LLM may propose calling during a completion.
///
/// Mirrors the OpenAI-compatible tool-use shape (`{name, description,
/// parameters}` with a JSON schema for parameters) because the LLM-facing
/// surface speaks the OpenAI dialect at every passthrough provider.
final class ToolDescriptor {
  /// Canonical tool name. The LLM proposes calls keyed by this name; the
  /// caller resolves the name back to a callable tool.
  final String name;

  /// Human-readable description fed to the LLM as part of the system prompt.
  /// Tone is "what the tool does and when to call it", not "how it is
  /// implemented".
  final String description;

  /// JSON-schema-shaped parameter spec. Pass `{}` for parameter-less tools.
  final Map<String, Object?> parametersSchema;

  const ToolDescriptor({
    required this.name,
    required this.description,
    required this.parametersSchema,
  });
}
