/// A first-class JSON serialization contract for plain value objects.
///
/// The framework can already serialize three kinds of value directly: a
/// reflected `TomClass` (via its `toJson`), a `Map`, and a `List`. Everything
/// else falls back to the reflection serializer, which reads a type's reflected
/// fields — it skips `final` fields and looks for a `jsonEncode` getter rather
/// than a `toJson` method. A plain data-transfer object with all-`final` fields
/// (the common shape for an immutable wire DTO) therefore serializes to `{}` or
/// fails outright, even when it already carries a perfectly good `toJson`.
///
/// Implement [TomJsonSerializable] to give such a DTO an explicit, reflection-
/// free serialization path. Consumers that render a value to JSON (notably the
/// server endpoint pipeline) check for this interface before falling back to
/// reflection, and encode the object as its [toJson] map.
///
/// ```dart
/// class LoginResult implements TomJsonSerializable {
///   final String token;
///   const LoginResult(this.token);
///
///   @override
///   Map<String, Object?> toJson() => {'token': token};
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
