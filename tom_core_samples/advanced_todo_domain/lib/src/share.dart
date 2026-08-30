import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'enums.dart';
import 'user.dart';

/// A cross-user access record: grants a principal a role on a resource.
///
/// The mechanism behind "Alice shares Project X with Bob as editor" — the app
/// server resolves resource-level access by looking for a [Share] whose
/// [granteeUserId] matches the principal and whose ([resourceType],
/// [resourceId]) covers the requested object or one of its ancestors.
///
/// [projectRole] is stored as the [ProjectRole] name in a `TomString`; use
/// [projectRoleValue] for the typed enum.
@tomReflector
class Share extends TomClass {
  /// Stable identifier (the server's primary key).
  late final id = TomString('');

  /// Kind of resource granted, e.g. `workspace`/`project`/`list`/`item`.
  late final resourceType = TomString('');

  /// Identifier of the granted resource within [resourceType].
  late final resourceId = TomString('');

  /// [User.id] the access is granted to.
  late final granteeUserId = TomString('');

  /// Role granted on the resource, stored as a [ProjectRole] name
  /// ([EnumName.name]); use [projectRoleValue] for the typed enum.
  late final projectRole = TomString(ProjectRole.viewer.name);

  /// [User.id] of the principal who created the share.
  late final grantedById = TomString('');

  /// When the share was created; null until persisted.
  late final createdAt = TomNDateTime(null);

  /// Typed view of [projectRole]; falls back to [ProjectRole.viewer] (the
  /// least-privileged role) for an unknown stored value.
  ProjectRole get projectRoleValue =>
      ProjectRole.values.asNameMap()[projectRole.get()] ?? ProjectRole.viewer;

  set projectRoleValue(ProjectRole value) => projectRole.set(value.name);
}
