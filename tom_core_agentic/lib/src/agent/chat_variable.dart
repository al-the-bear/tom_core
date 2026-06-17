// ChatVariable — a named binding the placeholder engine resolves `${name}`
// (and the `{{name}}` alias) against.
//
// Ported from the VS Code extension's chat-variable store for the TomSpecs
// editor (§11.4 / §11.5 of `tom_specs_editor_specification.md`). Chat
// variables are the user-facing binding source the §11.5 placeholder
// resolution reads: each variable contributes one `name → value` entry to the
// resolver's stack. Built-in variables (`date`, `time`, `quest`, …) are
// supplied by the composer at resolution time and carry [builtIn] so an editor
// can render them read-only; custom variables are authored and persisted.
library;

/// A single placeholder binding identified by its [name].
final class ChatVariable {
  const ChatVariable({
    required this.name,
    this.value = '',
    this.description = '',
    this.builtIn = false,
  });

  /// The placeholder name this variable binds — `${name}` / `{{name}}` expand
  /// to [value]. Identity of the variable within a store.
  final String name;

  /// The text substituted for the placeholder.
  final String value;

  /// Optional human-readable note shown in the chat-variables editor (§12).
  final String description;

  /// Whether this is a composer-supplied built-in (read-only in the editor)
  /// rather than a user-authored variable. Built-ins are not persisted.
  final bool builtIn;

  factory ChatVariable.fromYaml(Map<String, dynamic> yaml) => ChatVariable(
        name: yaml['name'] as String,
        value: yaml['value'] as String? ?? '',
        description: yaml['description'] as String? ?? '',
        builtIn: yaml['builtIn'] as bool? ?? false,
      );

  Map<String, dynamic> toYaml() => <String, dynamic>{
        'name': name,
        'value': value,
        'description': description,
        'builtIn': builtIn,
      };

  /// Folds [variables] into a `name → value` bindings map (later entries win
  /// on a name clash), ready to feed an `EditorPlaceholderBindings`.
  static Map<String, String> bindingsOf(Iterable<ChatVariable> variables) =>
      <String, String>{
        for (final variable in variables) variable.name: variable.value,
      };
}
