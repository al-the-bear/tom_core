// CapturedWirePrompt — a data-only mirror of the wire body a provider saw.
//
// Migrated into `tom_core_agentic` from the tom_brain substrate api/ layer
// (originally `tom_brain_substrate/lib/src/api/captured_wire.dart`). A trail
// writer needs the full wire body to record what the provider received, but
// `WirePrompt` stays a provider-facing type a consumer must not construct. The
// wire body therefore crosses to consumers as this data-only mirror: it carries
// the provenance a trail writer needs (body + anchorHash + roleId + templateSha)
// and nothing that lets a consumer reconstruct a wire and bypass assembly.
final class CapturedWirePrompt {
  /// The assembled wire body — the anchor scaffold string the provider
  /// received. Serialised verbatim by the trail writer; not re-rendered
  /// downstream.
  final String body;

  /// SHA of the dedication anchor block embedded in [body]. Equals the
  /// `anchorHash` of the call's terminal [LlmCallReport].
  final String anchorHash;

  /// The role the wire was assembled for (e.g. `assistant_to_user`).
  final String roleId;

  /// SHA of the role template that produced [body], when the role carried one.
  /// `null` for roles assembled without a template.
  final String? templateSha;

  const CapturedWirePrompt({
    required this.body,
    required this.anchorHash,
    required this.roleId,
    this.templateSha,
  });
}
