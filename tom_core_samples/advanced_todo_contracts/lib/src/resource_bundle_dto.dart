import 'package:tom_core_kernel/tom_core_kernel.dart' show TomJsonSerializable;

/// A bundle of UI display resources (texts) a server delivers to a client, so
/// the client's forms resolve their labels, hints and error messages without
/// shipping any UI strings of their own.
///
/// [texts] is keyed by the `<basePath>.<suffix>` convention the Tom resource
/// resolver uses — `todo.item.title.label`, `login.username.hint`,
/// `todo.item.estimate.error.required`, … — the exact shape
/// `TomTextResourceProvider.from` accepts (flat dotted keys, or nested maps for
/// a shared prefix). A client installs a received bundle verbatim via
/// `TomTextResourceProvider.from(dto.texts)`; the keys agree with the form
/// fields' `basePath`s because both are governed by the one
/// `advanced_todo_domain` scope/form/field convention (todo 1), so a resource
/// key cannot drift from the field it labels.
///
/// Texts-only for now: configuration, colours and icons can extend the DTO
/// later without reshaping the call. The map is held as an unmodifiable copy so
/// a bundle never mutates under a caller, and equality is structural and deep
/// (so a nested-map bundle compares by value, order-independent at each level).
///
/// Implements [TomJsonSerializable] so the endpoint pipeline serializes a
/// single-`ResourceBundleDto` result (the resource endpoints) through [toJson]
/// rather than the reflection serializer, which would drop its `final` field.
class ResourceBundleDto implements TomJsonSerializable {
  final Map<String, Object?> _texts;

  /// Wraps [texts] (`<basePath>.<suffix>` → value) as an unmodifiable copy. A
  /// `null`/omitted argument yields an empty bundle.
  ResourceBundleDto([Map<String, Object?>? texts])
      : _texts = Map<String, Object?>.unmodifiable(texts ?? const {});

  /// Rebuilds a bundle from its JSON shape `{texts: {...}}`. A missing or
  /// non-map `texts` yields an empty bundle.
  factory ResourceBundleDto.fromJson(Map<String, Object?> json) {
    final raw = json['texts'];
    return ResourceBundleDto(
      raw is Map ? raw.cast<String, Object?>() : const {},
    );
  }

  /// An unmodifiable view of the bundle's `<basePath>.<suffix>` → value map,
  /// ready to hand straight to `TomTextResourceProvider.from`.
  Map<String, Object?> get texts => _texts;

  /// JSON shape `{texts: {...}}`, the map verbatim.
  @override
  Map<String, Object?> toJson() => {'texts': _texts};

  @override
  bool operator ==(Object other) =>
      other is ResourceBundleDto && _deepEquals(_texts, other._texts);

  @override
  int get hashCode => _deepHash(_texts);

  @override
  String toString() => 'ResourceBundleDto(${_texts.length} keys)';

  /// Structural deep equality over maps, lists and scalars — so a bundle with
  /// nested-map values still compares by value.
  static bool _deepEquals(Object? a, Object? b) {
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_deepEquals(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }

  /// Order-independent deep hash matching [_deepEquals].
  static int _deepHash(Object? value) {
    if (value is Map) {
      var hash = 0;
      value.forEach((key, val) => hash ^= Object.hash(key, _deepHash(val)));
      return hash;
    }
    if (value is List) {
      return Object.hashAll(value.map(_deepHash));
    }
    return value.hashCode;
  }
}
