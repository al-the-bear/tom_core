/// Entity barrel — the public model surface (no generated code).
///
/// Re-exported by `todo_domain.dart`. The reflection generator's root is the
/// separate `reflection_entry.dart` (it needs a `main()`); this barrel only
/// carries the hand-written entities so importing it never pulls in generated
/// output.
library;

// not-exported: reflection_entry.dart — the reflection generator's root, which
// exists only to give the generator a `main()` to follow imports from. It is
// never called at runtime, and exporting it would put that `main` into the
// namespace of everyone importing the model. What consumers want from it,
// `initializeReflection`, reaches them through `todo_domain.dart` instead.

export 'enums.dart';
export 'project.dart';
export 'todo_item.dart';
export 'todo_list.dart';
export 'user.dart';
