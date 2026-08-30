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
///
/// The id segment is **decimal text** — the server's surrogate key rendered — so
/// the builders take it as a [String]. That is not a widening for convenience:
/// the two tiers hold the same id in different Dart types (the server an `int`
/// column, a client a reflected `TomString`), and a key is a string either way.
/// Typing the builders on `int` made them unusable on the client tier without
/// an `int.parse`, which is how the format ended up hand-interpolated there.
/// Servers render at the call site (`id.toString()`); clients pass `id.get()`.
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
  ///
  /// [id] is the surrogate key in its decimal text form. Callers holding an
  /// `int` render it (`id.toString()`); callers holding a reflected `TomString`
  /// pass `id.get()`. The app server's `parseResourceKey` is the inverse and is
  /// the stricter of the two — it rejects a non-decimal id segment — so this
  /// builder is the *only* thing that should ever write the separator.
  static String forResource(String type, String id) => '$type:$id';

  /// The resource key for the workspace with surrogate [id].
  static String workspace(String id) => forResource(workspaceType, id);

  /// The resource key for the project with surrogate [id].
  static String project(String id) => forResource(projectType, id);

  /// The resource key for the list with surrogate [id].
  static String list(String id) => forResource(listType, id);

  /// The resource key for the item with surrogate [id].
  static String item(String id) => forResource(itemType, id);
}
