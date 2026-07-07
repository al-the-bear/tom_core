/// Closed-set enums shared by the todo-management domain model.
///
/// Both enums are stored on their owning entity as the enum's
/// [Enum.name] (a `TomString`), so they round-trip cleanly to the
/// server's persistence layer and JSON without a custom codec. The
/// typed accessors on [TodoItem] convert back to these enums.
///
/// The enums carry **no** hardcoded display strings (G-RES-5): a value's
/// user-facing text is a resource key ([EnumResourceKey.resourceKey]) resolved
/// through the installed resource bundle at the point of display.
library;

/// Priority of a [TodoItem], lowest to highest.
enum TodoPriority { low, medium, high, critical }

/// Category label for a [TodoItem].
enum TodoLabel { feature, bug, chore, docs, research }

/// The resource key under which an enum value's display text resolves (G-RES-5).
///
/// Shaped `global.<enumtype>.<value>` — e.g. [TodoPriority.critical] resolves as
/// `global.todopriority.critical`. Both segments are lower-cased: the enum type
/// name (`runtimeType`) and the value's [Enum.name]. The text itself lives in
/// the installed resource bundle, so an enum never carries a hardcoded display
/// string; the UI resolves this key through the text-resource provider at use.
extension EnumResourceKey on Enum {
  /// This value's `global.<enumtype>.<value>` display-text resource key.
  String get resourceKey =>
      'global.${runtimeType.toString().toLowerCase()}.${name.toLowerCase()}';
}
