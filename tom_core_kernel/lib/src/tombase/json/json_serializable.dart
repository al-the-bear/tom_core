/// The declaration that a value object serializes itself.
///
/// **Reflection is the default.** Tom Core serializes wire types — requests,
/// responses, DTOs, and the framework's own value objects alike — through the
/// reflection path, driven from two central entry points: one outbound, one
/// inbound. Reflection is not a fallback of last resort; it is how the wire
/// contract is meant to work, and a type should need nothing beyond
/// `@tomReflectable` plain mutable fields to cross it.
///
/// Two consequences follow, and they are worth stating plainly:
///
/// - **A `final` field cannot participate.** A `final` field is unassignable
///   after construction, so no reflective deserializer can ever populate it.
///   This is inherent to the language, not a gap in the serializer. `final`
///   members in request and response classes are therefore **discouraged**
///   across Tom Core; declare wire members as plain mutable fields.
/// - **Framework types are not exempt.** Every entrypoint runs
///   `reflection_generator`, and the generated seed spans the whole dependency
///   closure — `tom_core_kernel` types included. A framework value object does
///   not need a hand-written codec to stay independent of an application's
///   reflection domain, because it is already inside it.
///
/// **What this interface is for.** Some types genuinely do need to control their
/// own JSON — a legacy external wire shape, say. [TomJsonSerializable] is how
/// they say so, and its value is that saying so is *cheap to detect*: an `is`
/// check, resolved at the two central entry points before the field walk begins.
/// No mirror round-trip, no invoking a speculative member and catching the
/// failure to decide whether it existed. That is the whole point of the
/// interface — it makes "this type serializes itself" a type-system fact rather
/// than something the serializer has to probe for.
///
/// It is an escape hatch, not the design default. A type that implements it
/// should be a shape adapter carrying no business or security logic; if the only
/// reason for the manual path is a member name that does not match the wire
/// name, rename the member or the field instead.
///
/// ```dart
/// class LegacyPingResult implements TomJsonSerializable {
///   String status = '';
///
///   // The upstream service has spelled this field `ok` since 2011.
///   @override
///   Map<String, Object?> toJson() => {'ok': status};
/// }
/// ```
library;

/// Marks a value object that renders itself to a JSON-encodable map.
abstract interface class TomJsonSerializable {
  /// The JSON-encodable representation of this object — a map whose values are
  /// themselves `jsonEncode`-able (primitives, lists, maps, or other
  /// already-encoded values).
  Map<String, Object?> toJson();
}
