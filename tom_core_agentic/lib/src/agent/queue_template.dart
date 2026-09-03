// QueueTemplate — a saved set of prompts that can be loaded into the queue.
//
// Ported from the VS Code extension's queue-template store for the TomSpecs
// editor (§11.2 / §11.4). A queue template names an ordered list of prompt
// bodies; applying it appends those prompts (each still placeholder-bearing,
// resolved at send time) to the live prompt queue. The queue-templates editor
// (§12) saves/loads these as `*.template.queue.yaml`.
library;

/// A named, ordered set of prompt bodies identified by [id].
final class QueueTemplate {
  const QueueTemplate({
    required this.id,
    required this.name,
    this.prompts = const <String>[],
  });

  /// Stable identifier referenced by the queue-templates editor.
  final String id;

  /// Human-readable label.
  final String name;

  /// The ordered prompt bodies applied to the queue, head first. Each is
  /// authored with the §11.5 placeholder forms and resolved at send time.
  final List<String> prompts;

  factory QueueTemplate.fromYaml(Map<String, dynamic> yaml) {
    final raw = yaml['prompts'];
    return QueueTemplate(
      id: yaml['id'] as String,
      name: yaml['name'] as String? ?? '',
      prompts: raw is List
          ? <String>[for (final p in raw) '$p']
          : const <String>[],
    );
  }

  Map<String, dynamic> toYaml() => <String, dynamic>{
    'id': id,
    'name': name,
    'prompts': List<String>.from(prompts),
  };
}
