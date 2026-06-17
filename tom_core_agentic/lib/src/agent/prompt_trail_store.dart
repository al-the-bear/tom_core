// Persistence for the prompt trail (§11.3).
//
// The trail's request/answer pairs are held in the spec workspace as a YAML
// file so the exchange history survives launches (mirroring
// `_ai/trail/anthropic/{quest}/`). Like the other editor sidecars it writes
// synchronously on every change and degrades to an empty trail on any
// read/parse error rather than throwing.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'agent_yaml.dart';
import 'chat_message.dart';

/// Loads/saves the editor prompt trail (`List<TrailPair>`) as YAML.
class PromptTrailStore {
  PromptTrailStore(this.file);

  /// The backing YAML file.
  final File file;

  /// Resolves the trail file. Honors `TOM_SPECS_TRAIL_FILE`; falls back to
  /// `<cwd>/.tom/prompt_trail.yaml`.
  factory PromptTrailStore.resolveDefault() {
    final override = Platform.environment['TOM_SPECS_TRAIL_FILE'];
    final path = (override != null && override.isNotEmpty)
        ? override
        : p.join(Directory.current.path, '.tom', 'prompt_trail.yaml');
    return PromptTrailStore(File(path));
  }

  /// Loads the persisted trail, or an empty list when the file is missing,
  /// unreadable or malformed.
  List<TrailPair> load() {
    try {
      if (!file.existsSync()) return <TrailPair>[];
      final content = file.readAsStringSync();
      if (content.trim().isEmpty) return <TrailPair>[];
      final root = decodeAgentYaml(content);
      final pairs = root['pairs'];
      if (pairs is! List) return <TrailPair>[];
      return [
        for (final pair in pairs)
          if (pair is Map) TrailPair.fromYaml(pair.cast<String, dynamic>()),
      ];
    } on FileSystemException {
      return <TrailPair>[];
    } on FormatException {
      return <TrailPair>[];
    }
  }

  /// Persists [trail], creating the parent directory if needed.
  void save(List<TrailPair> trail) {
    final yaml = encodeAgentYaml(<String, dynamic>{
      'version': 1,
      'pairs': [for (final pair in trail) pair.toYaml()],
    });
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(yaml);
  }
}
