import 'package:advanced_todo_domain/advanced_todo_domain.dart' show ProjectRole;

/// A request to share a resource with another user at a given role, posted to
/// `POST /share`.
///
/// The owner names the target ([resourceType] + [resourceId]), the grantee
/// ([granteeUserId]) and the [projectRole] to grant. The role travels as its
/// [ProjectRole.name] token; [fromJson] resolves an unknown token to the
/// least-privileged [ProjectRole.viewer] (closed-safe) rather than throwing.
class ShareRequest {
  /// Kind of resource being shared, e.g. `workspace`/`project`/`list`/`item`.
  final String resourceType;

  /// Identifier of the shared resource within [resourceType].
  final String resourceId;

  /// [UserDto.id] the access is granted to.
  final String granteeUserId;

  /// Role granted on the resource.
  final ProjectRole projectRole;

  /// Creates a share request. [projectRole] defaults to the least-privileged
  /// [ProjectRole.viewer].
  const ShareRequest({
    this.resourceType = '',
    this.resourceId = '',
    this.granteeUserId = '',
    this.projectRole = ProjectRole.viewer,
  });

  /// Rebuilds a request from its JSON shape. An unknown `projectRole` token
  /// degrades to [ProjectRole.viewer] (closed-safe).
  factory ShareRequest.fromJson(Map<String, Object?> json) => ShareRequest(
        resourceType: (json['resourceType'] as String?) ?? '',
        resourceId: (json['resourceId'] as String?) ?? '',
        granteeUserId: (json['granteeUserId'] as String?) ?? '',
        projectRole: ProjectRole.values.asNameMap()[json['projectRole']] ??
            ProjectRole.viewer,
      );

  /// JSON shape `{resourceType, resourceId, granteeUserId, projectRole}` with
  /// [projectRole] as its stable token.
  Map<String, Object?> toJson() => {
        'resourceType': resourceType,
        'resourceId': resourceId,
        'granteeUserId': granteeUserId,
        'projectRole': projectRole.name,
      };

  @override
  bool operator ==(Object other) =>
      other is ShareRequest &&
      other.resourceType == resourceType &&
      other.resourceId == resourceId &&
      other.granteeUserId == granteeUserId &&
      other.projectRole == projectRole;

  @override
  int get hashCode =>
      Object.hash(resourceType, resourceId, granteeUserId, projectRole);

  @override
  String toString() =>
      'ShareRequest($resourceType:$resourceId -> $granteeUserId as ${projectRole.name})';
}
