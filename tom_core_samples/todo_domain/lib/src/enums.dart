/// Closed-set enums shared by the todo-management domain model.
///
/// Both enums are stored on their owning entity as the enum's
/// [Enum.name] (a `TomString`), so they round-trip cleanly to the
/// server's persistence layer and JSON without a custom codec. The
/// typed accessors on [TodoItem] convert back to these enums.
library;

/// Priority of a [TodoItem], lowest to highest.
enum TodoPriority { low, medium, high, critical }

/// Human-facing labels for [TodoPriority].
extension TodoPriorityLabel on TodoPriority {
  /// Display text, e.g. `Critical` for [TodoPriority.critical].
  String get label => switch (this) {
        TodoPriority.low => 'Low',
        TodoPriority.medium => 'Medium',
        TodoPriority.high => 'High',
        TodoPriority.critical => 'Critical',
      };
}

/// Category label for a [TodoItem].
enum TodoLabel { feature, bug, chore, docs, research }

/// Human-facing labels for [TodoLabel].
extension TodoLabelText on TodoLabel {
  /// Display text, e.g. `Docs` for [TodoLabel.docs].
  String get label => switch (this) {
        TodoLabel.feature => 'Feature',
        TodoLabel.bug => 'Bug',
        TodoLabel.chore => 'Chore',
        TodoLabel.docs => 'Docs',
        TodoLabel.research => 'Research',
      };
}
