/// The canonical resource-key convention for per-principal-per-resource role
/// grants (C-5 `TomPrincipalResourceGrant.resourceKey` /
/// `TomAccessControlInformation.resourceRoles`).
///
/// A principal's role on a concrete resource (owner of *this* project, viewer of
/// *that* item) is stored as a grant keyed by a stable resource key, and folded
/// into the `resourceKey → roleName` map the bearer token carries. Both tiers and
/// every client must build that key the same way, so the format lives here — in
/// the shared domain — rather than being re-derived at each write and read site.
///
/// The key is `<type>:<id>`: the resource's kind ([workspaceType] / [projectType]
/// / [listType] / [itemType]) and its surrogate id. This mirrors the containment
/// vocabulary the sample already uses for shares (a share names the same four
/// types), so an ownership grant and a share on the same resource share one key
/// namespace.
library;

/// Builders and type tokens for the `<type>:<id>` resource keys that grants and
/// the `resourceRoles` map are keyed by.
class ResourceRoleKeys {
  const ResourceRoleKeys._();

  /// A whole workspace — the top of the containment chain.
  static const String workspaceType = 'workspace';

  /// A project within a workspace.
  static const String projectType = 'project';

  /// A list within a project.
  static const String listType = 'list';

  /// An item within a list.
  static const String itemType = 'item';

  /// Builds the `<type>:<id>` key for a resource of [type] with surrogate [id].
  static String forResource(String type, int id) => '$type:$id';

  /// The resource key for the workspace with surrogate [id].
  static String workspace(int id) => forResource(workspaceType, id);

  /// The resource key for the project with surrogate [id].
  static String project(int id) => forResource(projectType, id);

  /// The resource key for the list with surrogate [id].
  static String list(int id) => forResource(listType, id);

  /// The resource key for the item with surrogate [id].
  static String item(int id) => forResource(itemType, id);
}
