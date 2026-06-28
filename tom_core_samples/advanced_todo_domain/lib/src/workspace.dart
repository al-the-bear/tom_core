import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Top-level container a [User] owns; groups [Project]s.
///
/// Root of the ownership chain `Workspace → Project → TodoList → TodoItem`
/// that the app server walks to resolve resource-level access.
@tomReflector
class Workspace extends TomClass {
  /// Stable identifier (the server's primary key).
  late final id = TomString('');

  /// Display name, e.g. `Acme Engineering`.
  late final name = TomString('');

  /// [User.id] of the owning principal.
  late final ownerId = TomString('');

  /// When the workspace was created; null until persisted.
  late final createdAt = TomNDateTime(null);
}
