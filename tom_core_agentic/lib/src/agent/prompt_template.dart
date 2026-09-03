// PromptTemplate — a reusable, placeholder-bearing prompt body.
//
// Ported from the VS Code extension's prompt-template store for the TomSpecs
// editor (§11.4). A template's [body] is authored with the §11.5 placeholder
// forms (`${name}`, `{{name}}`, `${env:NAME}`) and resolved through the same
// composer the chat composer uses, giving the prompt-templates editor (§12) a
// live preview. The body is stored verbatim; resolution happens at use time so
// late-bound built-ins (`date`/`time`) reflect the moment of send.
library;

/// A reusable prompt body identified by [id].
final class PromptTemplate {
  const PromptTemplate({
    required this.id,
    required this.name,
    this.body = '',
    this.isUserMessage = false,
  });

  /// Stable identifier referenced by the editor / queue.
  final String id;

  /// Human-readable label shown in the prompt-templates editor.
  final String name;

  /// Template body using the §11.5 placeholder forms; resolved at use time.
  final String body;

  /// Whether this template seeds the composer's user-message field (vs. a
  /// reusable insertable snippet).
  final bool isUserMessage;

  factory PromptTemplate.fromYaml(Map<String, dynamic> yaml) => PromptTemplate(
    id: yaml['id'] as String,
    name: yaml['name'] as String? ?? '',
    body: yaml['body'] as String? ?? '',
    isUserMessage: yaml['isUserMessage'] as bool? ?? false,
  );

  Map<String, dynamic> toYaml() => <String, dynamic>{
    'id': id,
    'name': name,
    'body': body,
    'isUserMessage': isUserMessage,
  };
}
