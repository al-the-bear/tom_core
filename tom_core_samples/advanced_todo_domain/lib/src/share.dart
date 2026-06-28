import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A cross-user access record: grants a principal a role on a resource.
///
/// The mechanism behind "Alice shares Project X with Bob as editor" — the app
/// server resolves resource-level access by looking for a [Share] whose
/// [granteeUserId] matches the principal and whose ([resourceType],
/// [resourceId]) covers the requested object or one of its ancestors.
///
/// [projectRole] is stored as a role name (`owner`/`editor`/`commenter`/
/// `viewer`); the typed `projectRole` enum and its accessor are introduced with
/// the role constants in step 3 of the plan.
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

  /// Role name granted on the resource (`owner`/`editor`/`commenter`/`viewer`).
  late final projectRole = TomString('viewer');

  /// [User.id] of the principal who created the share.
  late final grantedById = TomString('');

  /// When the share was created; null until persisted.
  late final createdAt = TomNDateTime(null);
}
