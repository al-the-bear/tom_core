/// Closed-set enums shared by the advanced todo-management domain model.
///
/// Each enum is stored on its owning entity as the enum's [Enum.name] (a
/// `TomString`), so it round-trips cleanly to the server's SQL persistence and
/// JSON without a custom codec. The typed accessors on the entities convert the
/// stored name back to these enums, falling back to a sensible default for an
/// unknown value.
///
/// The enums carry **no** hardcoded display strings (G-RES-5): a value's
/// user-facing text is resolved through the server-sent resource bundle at the
/// point of display. The framework owns both halves of that — `TomObservableEnum`
/// derives the `global.<enumtype>.<value>` key and resolves it, and
/// `TomEnumNameSelectableSource` labels a name-valued picker from the same keys —
/// so this library declares the values and nothing else.
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
