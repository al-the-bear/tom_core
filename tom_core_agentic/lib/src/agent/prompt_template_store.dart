// Persistence for the reusable prompt-template set (§11.4, §12).
//
// Prompt templates (user-message seeds + reusable prompt bodies) are editor
// configuration held in the spec workspace as a YAML file. Mirrors
// [ChatVariableStore]: written synchronously on every change, degrading to an
// empty set on any read/parse error rather than throwing.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'agent_yaml.dart';
import 'prompt_template.dart';

/// Loads/saves the prompt-template set (`List<PromptTemplate>`) as YAML.
class PromptTemplateStore {
  PromptTemplateStore(this.file);

  /// The backing YAML file.
  final File file;

  /// Resolves the prompt-templates file. Honors `TOM_SPECS_PROMPT_TEMPLATES_FILE`;
  /// falls back to `<cwd>/.tom/prompt_templates.yaml`.
  factory PromptTemplateStore.resolveDefault() {
    final override = Platform.environment['TOM_SPECS_PROMPT_TEMPLATES_FILE'];
    final path = (override != null && override.isNotEmpty)
        ? override
        : p.join(Directory.current.path, '.tom', 'prompt_templates.yaml');
    return PromptTemplateStore(File(path));
  }

  /// Loads the persisted templates, or an empty list when the file is missing,
  /// unreadable or malformed.
  List<PromptTemplate> load() {
    try {
      if (!file.existsSync()) return <PromptTemplate>[];
      final content = file.readAsStringSync();
      if (content.trim().isEmpty) return <PromptTemplate>[];
      final root = decodeAgentYaml(content);
      final items = root['templates'];
      if (items is! List) return <PromptTemplate>[];
      return [
        for (final item in items)
          if (item is Map)
            PromptTemplate.fromYaml(item.cast<String, dynamic>()),
      ];
    } on FileSystemException {
      return <PromptTemplate>[];
    } on FormatException {
      return <PromptTemplate>[];
    }
  }

  /// Persists [templates], creating the parent directory if needed.
  void save(List<PromptTemplate> templates) {
    final yaml = encodeAgentYaml(<String, dynamic>{
      'version': 1,
      'templates': [for (final template in templates) template.toYaml()],
    });
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(yaml);
  }
}
