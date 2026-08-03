/// Closed-set enums shared by the todo-management domain model.
///
/// Both enums are stored on their owning entity as the enum's
/// [Enum.name] (a `TomString`), so they round-trip cleanly to the
/// server's persistence layer and JSON without a custom codec. The
/// typed accessors on [TodoItem] convert back to these enums.
///
/// The enums carry **no** hardcoded display strings (G-RES-5): a value's
/// user-facing text is resolved through the installed resource bundle at the
/// point of display. The framework owns both halves of that —
/// `TomObservableEnum` derives the `global.<enumtype>.<value>` key and resolves
/// it, and `TomEnumNameSelectableSource` labels a name-valued picker from the
/// same keys — so this library declares the values and nothing else.
library;

/// Priority of a [TodoItem], lowest to highest.
enum TodoPriority { low, medium, high, critical }

/// Category label for a [TodoItem].
enum TodoLabel { feature, bug, chore, docs, research }
