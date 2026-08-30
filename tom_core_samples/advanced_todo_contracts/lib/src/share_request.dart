import 'package:advanced_todo_domain/advanced_todo_domain.dart' show ProjectRole;
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A request to share a resource with another user at a given role, posted to
/// `POST /share`.
///
/// The owner names the target ([resourceType] + [resourceId]), the grantee
/// ([granteeUserId]) and the role to grant. The role travels as its
/// `ProjectRole.name` token under the wire key `projectRole`; use
/// [projectRoleValue] for the typed enum. An unset/unknown token resolves to the
/// least-privileged [ProjectRole.viewer] (closed-safe).
///
/// A reflection-first wire DTO (G-DTO): `@tomReflector`, plain non-`final`
/// fields, no hand-written serializer.
@tomReflector
class ShareRequest {
  /// Kind of resource being shared, e.g. `workspace`/`project`/`list`/`item`.
  String resourceType;

  /// Identifier of the shared resource within [resourceType].
  String resourceId;

  /// [UserDto.id] the access is granted to.
  String granteeUserId;

  /// Role granted on the resource, as its `ProjectRole.name` token; use
  /// [projectRoleValue] for the typed enum.
  String projectRole;

  /// Creates a share request. [projectRole] defaults to the least-privileged
  /// [ProjectRole.viewer].
  ShareRequest({
    this.resourceType = '',
    this.resourceId = '',
    this.granteeUserId = '',
    ProjectRole projectRole = ProjectRole.viewer,
  }) : projectRole = projectRole.name;

  /// Typed view of [projectRole]; an unset/unrecognised token resolves to
  /// [ProjectRole.viewer] (closed-safe).
  ProjectRole get projectRoleValue =>
      ProjectRole.values.asNameMap()[projectRole] ?? ProjectRole.viewer;

  /// Sets [projectRole] from a typed [ProjectRole].
  set projectRoleValue(ProjectRole value) => projectRole = value.name;

  @override
  String toString() =>
      'ShareRequest($resourceType:$resourceId -> $granteeUserId as $projectRole)';
}
