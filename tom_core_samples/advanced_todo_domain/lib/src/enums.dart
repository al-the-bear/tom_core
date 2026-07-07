/// Closed-set enums shared by the advanced todo-management domain model.
///
/// Each enum is stored on its owning entity as the enum's [Enum.name] (a
/// `TomString`), so it round-trips cleanly to the server's SQL persistence and
/// JSON without a custom codec. The typed accessors on the entities convert the
/// stored name back to these enums, falling back to a sensible default for an
/// unknown value.
///
/// The enums carry **no** hardcoded display strings (G-RES-5): a value's
/// user-facing text is a resource key ([EnumResourceKey.resourceKey]) resolved
/// through the server-sent resource bundle at the point of display.
library;

/// Workflow state of a `TodoItem` — the board column it currently sits in.
///
/// Replaces the binary "done" flag so the sample is a real board, not a
/// checklist.
enum TodoStatus { backlog, todo, inProgress, inReview, done, cancelled }

/// Priority of a `TodoItem`, lowest to highest.
enum TodoPriority { low, medium, high, critical }

/// Category label for a `TodoItem`.
enum TodoLabel { feature, bug, chore, docs, research }

/// Account lifecycle state of a `User`.
enum UserStatus { active, suspended }

/// The role a principal holds on a shared resource, most to least privileged.
///
/// The effective `ProjectRole` (from ownership or a `Share`) is what the
/// auth server's grant matrix keys field-level `TomAuthState` grades on. Stored
/// on a `Share` as the role's [Enum.name] in a `TomString`.
enum ProjectRole { owner, editor, commenter, viewer }

/// The resource key under which an enum value's display text resolves (G-RES-5).
///
/// Shaped `global.<enumtype>.<value>` — e.g. [TodoStatus.inReview] resolves as
/// `global.todostatus.inreview`. Both segments are lower-cased: the enum type
/// name (`runtimeType`) and the value's [Enum.name]. The text itself lives in
/// the server-sent resource bundle, so an enum never carries a hardcoded display
/// string; the UI resolves this key through the text-resource provider at use.
extension EnumResourceKey on Enum {
  /// This value's `global.<enumtype>.<value>` display-text resource key.
  String get resourceKey =>
      'global.${runtimeType.toString().toLowerCase()}.${name.toLowerCase()}';
}
