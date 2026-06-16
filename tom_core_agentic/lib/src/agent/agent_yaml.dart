// YAML codec for the editor-facing agent data models.
//
// Every agent model in this folder serialises to / from a plain
// `Map<String, dynamic>` (its `toYaml()` / `fromYaml()` pair). These two
// free functions move that map across the YAML text boundary so the
// TomSpecs editor can persist queues, profiles, templates, timed requests
// and chat-variable stores as `*.yaml` files in the spec workspace
// (§11.2 / §11.4 of `tom_specs_editor_specification.md`).
//
// `encodeAgentYaml` emits via `package:yaml_edit` (stable key order, block
// style); `decodeAgentYaml` parses via `package:yaml` and deep-converts the
// `YamlMap` / `YamlList` views into plain `Map` / `List` so the models'
// `fromYaml` factories never have to know about the YAML view types.
library;

import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// Serialises [data] to a YAML document string.
String encodeAgentYaml(Map<String, dynamic> data) {
  final editor = YamlEditor('{}');
  editor.update(<Object?>[], data);
  return editor.toString();
}

/// Parses a YAML document [yaml] into a plain `Map<String, dynamic>`.
///
/// Throws [FormatException] when the document's root is not a mapping.
Map<String, dynamic> decodeAgentYaml(String yaml) {
  final root = deepPlainYaml(loadYaml(yaml));
  if (root is! Map<String, dynamic>) {
    throw const FormatException('expected a YAML mapping at the document root');
  }
  return root;
}

/// Recursively converts a parsed YAML tree ([YamlMap] / [YamlList] / scalar)
/// into plain Dart collections. Map keys are coerced to `String`.
Object? deepPlainYaml(Object? node) {
  if (node is Map) {
    return <String, dynamic>{
      for (final entry in node.entries)
        entry.key.toString(): deepPlainYaml(entry.value),
    };
  }
  if (node is List) {
    return <dynamic>[for (final element in node) deepPlainYaml(element)];
  }
  return node;
}
