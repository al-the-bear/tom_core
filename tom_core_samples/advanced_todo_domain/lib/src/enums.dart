/// Closed-set enums shared by the advanced todo-management domain model.
///
/// Each enum is stored on its owning entity as the enum's [Enum.name] (a
/// `TomString`), so it round-trips cleanly to the server's SQL persistence and
/// JSON without a custom codec. The typed accessors on the entities convert the
/// stored name back to these enums, falling back to a sensible default for an
/// unknown value.
library;

/// Workflow state of a `TodoItem` — the board column it currently sits in.
///
/// Replaces the binary "done" flag so the sample is a real board, not a
/// checklist.
enum TodoStatus { backlog, todo, inProgress, inReview, done, cancelled }

/// Human-facing labels for [TodoStatus].
extension TodoStatusText on TodoStatus {
  /// Display text, e.g. `In review` for [TodoStatus.inReview].
  String get label => switch (this) {
        TodoStatus.backlog => 'Backlog',
        TodoStatus.todo => 'To do',
        TodoStatus.inProgress => 'In progress',
        TodoStatus.inReview => 'In review',
        TodoStatus.done => 'Done',
        TodoStatus.cancelled => 'Cancelled',
      };
}

/// Priority of a `TodoItem`, lowest to highest.
enum TodoPriority { low, medium, high, critical }

/// Human-facing labels for [TodoPriority].
extension TodoPriorityText on TodoPriority {
  /// Display text, e.g. `Critical` for [TodoPriority.critical].
  String get label => switch (this) {
        TodoPriority.low => 'Low',
        TodoPriority.medium => 'Medium',
        TodoPriority.high => 'High',
        TodoPriority.critical => 'Critical',
      };
}

/// Category label for a `TodoItem`.
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

/// Account lifecycle state of a `User`.
enum UserStatus { active, suspended }

/// Human-facing labels for [UserStatus].
extension UserStatusText on UserStatus {
  /// Display text, e.g. `Suspended` for [UserStatus.suspended].
  String get label => switch (this) {
        UserStatus.active => 'Active',
        UserStatus.suspended => 'Suspended',
      };
}
