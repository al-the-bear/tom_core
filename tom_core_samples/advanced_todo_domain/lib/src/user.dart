import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'enums.dart';
import 'todo_item.dart';
import 'workspace.dart';

/// An authenticated principal: owns [Workspace]s and is assigned [TodoItem]s.
///
/// The shared identity entity for the advanced sample — the auth server
/// authenticates it, the app server persists it, and a [TodoItem.assigneeId]
/// or [TodoItem.reporterId] points back at its [id].
///
/// [status] is stored as the [UserStatus] name in a `TomString`; use
/// [statusValue] for the typed enum.
@tomReflector
class User extends TomClass {
  /// Stable identifier (the server's primary key).
  late final id = TomString('');

  /// Login handle, unique per deployment.
  late final username = TomString('');

  /// Name shown in the UI.
  late final displayName = TomString('');

  /// Contact email.
  late final email = TomString('');

  /// Optional reference to an avatar asset; empty when unset.
  late final avatarRef = TomString('');

  /// Account state stored as a [UserStatus] name ([EnumName.name]); use
  /// [statusValue] for the typed enum.
  late final status = TomString(UserStatus.active.name);

  /// Typed view of [status]; falls back to [UserStatus.active] for an unknown
  /// stored value.
  UserStatus get statusValue =>
      UserStatus.values.asNameMap()[status.get()] ?? UserStatus.active;

  set statusValue(UserStatus value) => status.set(value.name);
}
