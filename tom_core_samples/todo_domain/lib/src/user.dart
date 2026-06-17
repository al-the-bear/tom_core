import 'package:tom_core_kernel/tom_core_kernel.dart';

/// An account that owns [Project]s and is assigned [TodoItem]s.
///
/// The shared identity entity for the todo-management samples: the server
/// authenticates and persists it, the client logs in as one, and a
/// [TodoItem.assigneeId] points back at its [id].
@tomReflector
class User extends TomClass {
  /// Stable identifier (the server's primary key).
  late final id = TomString('');

  /// Name shown in the UI.
  late final displayName = TomString('');

  /// Login / contact email.
  late final email = TomString('');

  /// Role key driving four-state authorization, e.g. `owner`, `member`,
  /// `viewer`.
  late final role = TomString('member');
}
