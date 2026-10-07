part of 'acl_builder.dart';

/// Naming and grouping: ids for the container, rows and components, the
/// groups they belong to, and the controller that shows or hides groups.
extension AclBuilderIdentity on AclBuilder {
  // ── IDs ────────────────────────────────────────────────────────────────────

  AclBuilder setAclId(String id) {
    _aclId = id;
    return this;
  }

  /// Sets whether this container's ID contributes to descendant paths.
  ///
  /// - `true` — identity container: descendants see `c-<id>` in their paths.
  /// - `false` — layout container (default): ID is for own resources/auth only.
  AclBuilder setAclIdScope(bool idScope) {
    _idScope = idScope;
    return this;
  }

  AclBuilder setRowId(String id) {
    _currentRow.id = id;
    return this;
  }

  /// Sets whether the current row's ID contributes to descendant paths.
  ///
  /// - `true` — identity row: components inside see `rw-<id>` in their paths.
  /// - `false` — layout row (default): ID is for own resources/auth only.
  AclBuilder setRowIdScope(bool idScope) {
    _currentRow.idScope = idScope;
    return this;
  }

  AclBuilder setId(String id) {
    _requireComponent('setId').id = id;
    return this;
  }

  // ── Groups ─────────────────────────────────────────────────────────────────

  AclBuilder startGroup(String name) {
    if (_activeGroupName != null) {
      throw UnsupportedError(
        'AclBuilder: startGroup("$name") called while group "$_activeGroupName" '
        'is already active. Call endGroup() first.',
      );
    }
    _activeGroupName = name;
    return this;
  }

  AclBuilder endGroup() {
    if (_activeGroupName == null) {
      throw UnsupportedError(
        'AclBuilder: endGroup() called without a matching startGroup().',
      );
    }
    _activeGroupName = null;
    return this;
  }

  AclBuilder group(String name) {
    _requireComponent('group').group = name;
    return this;
  }

  /// Puts the whole container in group [name]: every row and component that
  /// does not name a group of its own joins it (see [AclContainer.aclGroup]).
  AclBuilder setAclGroup(String name) {
    _aclGroup = name;
    return this;
  }

  AclBuilder setRowGroup(String name) {
    _currentRow.group = name;
    return this;
  }

  // ── Visibility ─────────────────────────────────────────────────────────────

  AclBuilder setGroupVisibilityController(
    String groupName,
    AclGroupVisibilityController controller,
  ) {
    _groupVisibilityControllers[groupName] = controller;
    return this;
  }
}
