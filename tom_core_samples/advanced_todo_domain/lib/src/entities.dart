/// Entity barrel — the public model surface (no generated code).
///
/// Re-exported by `advanced_todo_domain.dart`. The reflection generator's root
/// is the test-only seed `test/run_all_tests.dart` (it needs a `main()`); this
/// barrel only carries the hand-written entities + enums so importing it never
/// pulls in generated output.
///
/// Because this barrel folds all eight files into one library, `dartdoc` resolves
/// a `[Sibling]` reference between any two of them whether or not the referring
/// file imports the sibling — so a broken cross-entity link is invisible in the
/// generated output. The analyzer resolves the same reference against the
/// *defining file's* import scope, and disagrees. The package therefore enables
/// the `comment_references` lint (`analysis_options.yaml`) and follows the rule
/// it enforces: **bracket a reference when the declaration is in the referring
/// file's scope, backtick it otherwise.** Entity files import the siblings they
/// document, so entity↔entity and entity→enum links are bracketed and navigable
/// in an IDE. `enums.dart` imports nothing from the domain — it is the leaf every
/// entity depends on — so the entities that own an enum are named in backticks
/// there rather than importing them back for a doc link. Framework types the
/// domain does not depend on (server-side `TomColumnAuthorization`, for instance)
/// are named the same way.
library;

export 'enums.dart';
export 'project.dart';
export 'share.dart';
export 'subtask.dart';
export 'todo_comment.dart';
export 'todo_item.dart';
export 'todo_list.dart';
export 'user.dart';
export 'workspace.dart';
