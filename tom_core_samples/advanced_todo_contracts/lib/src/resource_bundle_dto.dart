import 'package:tom_core_kernel/tom_core_kernel.dart';

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
/// `advanced_todo_domain` scope/form/field convention, so a resource key cannot
/// drift from the field it labels.
///
/// A reflection-first wire DTO (G-DTO): `@tomReflector`, a single plain
/// non-`final` [texts] field, no hand-written serializer. The reflection
/// serializer round-trips it as `{texts: {...}}`. Texts-only for now:
/// configuration, colours and icons can extend the DTO later without reshaping
/// the call.
@tomReflector
class ResourceBundleDto {
  /// The `<basePath>.<suffix>` → value map, ready to hand straight to
  /// `TomTextResourceProvider.from`.
  Map<String, Object?> texts;

  /// Wraps [texts] (`<basePath>.<suffix>` → value) into the bundle. A
  /// `null`/omitted argument yields an empty bundle.
  ResourceBundleDto([Map<String, Object?>? texts]) : texts = {...?texts};

  @override
  String toString() => 'ResourceBundleDto(${texts.length} keys)';
}

/// Flattens a nested resource [tree] (scope → form → field → suffix) into the
/// flat `<basePath>.<suffix>` → value map a [ResourceBundleDto] carries on the
/// wire.
///
/// The servers externalize their UI texts as nested JSON assets that mirror the
/// clients' scope/form/field hierarchy — e.g.
/// `{"todo": {"item": {"title": {"label": "Title"}}}}`. Flattening joins each
/// path segment with `.`, so that tree yields `todo.item.title.label → "Title"`:
/// exactly the key a field at `basePath` `todo.item.title` resolves its label
/// from. Only *map* nodes are descended into; the first non-map value terminates
/// a key, so scalar leaves (`"board.title": "My Board"`) flatten as written.
///
/// This is the inverse of the `TomTextResourceProvider` nested-map dot-notation
/// lookup: a client could install the nested tree directly, but the servers
/// flatten first so the served bundle stays the flat shape the wire contract and
/// the resource-endpoint tests already pin.
Map<String, Object?> flattenResourceTree(Map<String, dynamic> tree) {
  final flat = <String, Object?>{};
  void walk(String prefix, Map<dynamic, dynamic> node) {
    node.forEach((key, value) {
      final path = prefix.isEmpty ? '$key' : '$prefix.$key';
      if (value is Map) {
        walk(path, value);
      } else {
        flat[path] = value;
      }
    });
  }

  walk('', tree);
  return flat;
}
