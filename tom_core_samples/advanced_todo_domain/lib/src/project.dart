import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'todo_list.dart';
import 'workspace.dart';

/// A project inside a [Workspace]; groups [TodoList]s.
///
/// Relations are flat foreign keys ([workspaceId]) rather than nested lists, so
/// each entity maps to its own SQL table in the app server's persistence layer.
@tomReflector
class Project extends TomClass {
  /// Stable identifier (the server's primary key).
  late final id = TomString('');

  /// [Workspace.id] this project belongs to.
  late final workspaceId = TomString('');

  /// Display name, e.g. `Website relaunch`.
  late final name = TomString('');

  /// Free-form summary shown on the project header.
  late final description = TomString('');

  /// UI accent colour as a hex string, e.g. `#3366FF`; empty when unset.
  late final colour = TomString('');

  /// Whether the project is archived (hidden from the active board).
  late final archived = TomBool(false);
}
