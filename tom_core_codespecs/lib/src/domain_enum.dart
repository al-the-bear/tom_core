/// A single member of a [TomDomainEnum] — one named value in a domain's closed
/// value set.
///
/// The [valueId] is the stable wire/storage token; [label] is the display text
/// (which may be re-copied without changing the token). This separation lets a
/// domain enum drive both persistence (via CE-DB columns typed by the enum) and
/// UI (a `@OneOf` discriminator source, `codespecs_mapping.md` §9/csm7) without
/// coupling storage to display copy.
class TomDomainEnumValue {
  /// Stable identifier of the value (e.g. `pending`). Stable across renames of
  /// [label]; this is the token stored/transmitted.
  String valueId;

  /// Human-readable label for the value (e.g. `Pending payment`).
  String label;

  /// Optional description clarifying when the value applies.
  String? description;

  /// Creates a domain-enum value.
  TomDomainEnumValue({
    this.valueId = '',
    this.label = '',
    this.description,
  });
}

/// The domain-enum holder a CodeSpec's `@CsEnum` (the `domainEnum` member
/// kind) is built on.
///
/// **Why this is a gap (csm4 survey `codespecs_mapping.md` §5, verdict
/// *gap*).** `tom_core_kernel` carries only *mechanical* enums — `TomHttpMethod`,
/// `TomMimeType` and similar transport/plumbing sets — and no **domain-enum /
/// value-object framework** that names a business-domain closed value set as a
/// first-class, spec-authorable unit (its id, its members, and each member's
/// stable token vs. display label). A CodeSpecs data model needs that unit: a
/// `@CsEnum` marks a domain enumeration (e.g. `OrderStatus { pending, paid,
/// shipped }`) that is referenced by both the shared entity shape (CE-DB) and the
/// UI (`@OneOf` discriminators). So it lands here as a concrete `tom_core`-family
/// class — never an abstract `Cs*` base (the framework carries annotations only,
/// §0).
///
/// A CodeSpec `@CsEnum` class *is a* `TomDomainEnum`. `domainEnum` is a
/// **member kind, not a part** (`codespecs_mapping.md` §4.1) — `@CsEnum` lives
/// with the shared contract markers (`contract_annotations.dart`), so a domain
/// enum referenced by a shared contract type lives in the shared project of the
/// three-project output trio (§4.2) and is visible to both client and server;
/// otherwise it lives in the project of the part that introduces it.
class TomDomainEnum {
  /// Stable identifier of the enumeration (e.g. `order_status`).
  String enumId;

  /// Human-readable name of the enumeration.
  String displayName;

  /// The closed set of members, in declaration order.
  List<TomDomainEnumValue> values;

  /// The [TomDomainEnumValue.valueId] applied when nothing is set, or `null`
  /// when the enum has no default (a value must always be chosen).
  String? defaultValueId;

  /// Creates a domain-enum holder.
  TomDomainEnum({
    this.enumId = '',
    this.displayName = '',
    List<TomDomainEnumValue>? values,
    this.defaultValueId,
  }) : values = values ?? <TomDomainEnumValue>[];

  /// Whether [id] names a member of this enumeration.
  bool hasValue(String id) => values.any((v) => v.valueId == id);
}
