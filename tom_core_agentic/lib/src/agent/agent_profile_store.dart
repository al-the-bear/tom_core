// Persistence for the Anthropic agent-profile set (§7.1, §11.4, §12).
//
// Profiles are editor configuration held in the spec workspace as a YAML file
// so the user's personas survive launches. Mirrors [ChatVariableStore]: a small
// YAML file written synchronously on every change, degrading to an empty set on
// any read/parse error rather than throwing.
//
// Held **out of** the document `*.docspecs.yaml` pass — profiles are editor
// configuration, not specification content.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'agent_profile.dart';
import 'agent_yaml.dart';

/// Loads/saves the agent-profile set (`List<AgentProfile>`) as YAML.
class AgentProfileStore {
  AgentProfileStore(this.file);

  /// The backing YAML file.
  final File file;

  /// Resolves the profiles file. Honors `TOM_SPECS_PROFILES_FILE`; falls back
  /// to `<cwd>/.tom/agent_profiles.yaml`.
  factory AgentProfileStore.resolveDefault() {
    final override = Platform.environment['TOM_SPECS_PROFILES_FILE'];
    final path = (override != null && override.isNotEmpty)
        ? override
        : p.join(Directory.current.path, '.tom', 'agent_profiles.yaml');
    return AgentProfileStore(File(path));
  }

  /// Loads the persisted profiles, or an empty list when the file is missing,
  /// unreadable or malformed.
  List<AgentProfile> load() {
    try {
      if (!file.existsSync()) return <AgentProfile>[];
      final content = file.readAsStringSync();
      if (content.trim().isEmpty) return <AgentProfile>[];
      final root = decodeAgentYaml(content);
      final items = root['profiles'];
      if (items is! List) return <AgentProfile>[];
      return [
        for (final item in items)
          if (item is Map)
            AgentProfile.fromYaml(item.cast<String, dynamic>()),
      ];
    } on FileSystemException {
      return <AgentProfile>[];
    } on FormatException {
      return <AgentProfile>[];
    }
  }

  /// Persists [profiles], creating the parent directory if needed.
  void save(List<AgentProfile> profiles) {
    final yaml = encodeAgentYaml(<String, dynamic>{
      'version': 1,
      'profiles': [for (final profile in profiles) profile.toYaml()],
    });
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(yaml);
  }
}
