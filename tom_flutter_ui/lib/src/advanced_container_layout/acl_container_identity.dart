/// Identity and authorization: the group mode in force, the policy path a row
/// and a component resolve to, the scope published around a component, and
/// the pre-layout hiding pass that keys on a child's own auth state.
///
/// The two path builders sit together on purpose. They compose the same
/// segments in the same order and differ in one rule, and the defect that put
/// them here was each enforcing a rule the other did not.
///
/// See `acl_container.dart` for why these are parts rather than libraries.
part of 'acl_container.dart';

extension _AclIdentity on _AclContainerState {
  /// The group [row] belongs to: its own, or else the container's
  /// [AclContainer.aclGroup].
  ///
  /// The container's group is the outermost default, the same way a row's
  /// group is the default for the components in it: `setAclGroup` groups a
  /// whole container with one call, and anything named more narrowly keeps its
  /// own group.
  String? _rowGroup(AclRow row) => row.group ?? widget.aclGroup;

  /// The group [component] belongs to: its own, else its row's, else the
  /// container's. Resolved here once, because the answer is used three ways —
  /// the visibility mode in force, the policy path, and the identity published
  /// in [AclScope] — and three copies of the fallback chain could disagree.
  String? _componentGroup(AclComponent component, AclRow row) =>
      component.group ?? _rowGroup(row);

  /// Returns the visibility mode for a given group name, or [visible] if
  /// no controller is registered.
  AclGroupVisibilityMode _groupMode(String? groupName) {
    if (groupName == null) return AclGroupVisibilityMode.visible;
    final ctrl = widget.groupVisibilityControllers[groupName];
    return ctrl?.mode ?? AclGroupVisibilityMode.visible;
  }

  /// Builds the canonical policy path for an ACL component ID.
  ///
  /// Uses [TomScope.current.getScopePath()] as the identity base, then appends
  /// group/row/widget segments.
  ///
  /// The container's [AclContainer.aclId] and the row's [AclRow.id] are
  /// *descendant* segments, so each appears only when the corresponding
  /// `idScope` opts in: a layout container / layout row keeps its id for its
  /// own resources without namespacing everything beneath it.
  String _buildComponentPolicyPath({
    required String componentId,
    required AclRow row,
    String? groupName,
  }) {
    final scopePath = TomScope.current.getScopePath();
    final segments = <String>[];

    if (scopePath.isNotEmpty) segments.add(scopePath);

    // Add container self-segment if this ACL is an identity container.
    if (widget.idScope && widget.aclId != null && widget.aclId!.isNotEmpty) {
      segments.add(widget.aclId!);
    }

    if (groupName != null && groupName.isNotEmpty) {
      segments.add(groupName);
    }

    if (row.idScope && row.id != null && row.id!.isNotEmpty) {
      segments.add(row.id!);
    }

    segments.add(componentId);
    return segments.join('.');
  }

  /// Builds the canonical policy path for an ACL row ID.
  ///
  /// Uses [TomScope.current.getScopePath()] as the identity base.
  ///
  /// The row's own id is always the terminal segment — that is what "the id is
  /// for the row's own resources" means — but the container id above it is a
  /// descendant segment and so honours [AclContainer.idScope].
  String _buildRowPolicyPath({required String rowId, String? groupName}) {
    final scopePath = TomScope.current.getScopePath();
    final segments = <String>[];

    if (scopePath.isNotEmpty) segments.add(scopePath);

    if (widget.idScope && widget.aclId != null && widget.aclId!.isNotEmpty) {
      segments.add(widget.aclId!);
    }

    if (groupName != null && groupName.isNotEmpty) {
      segments.add(groupName);
    }

    segments.add(rowId);
    return segments.join('.');
  }

  /// Wraps a component with [AclScope], so anything inside it can read the
  /// identity the container resolved for it.
  ///
  /// [groupName] and [fullPath] are **required** and passed in already
  /// resolved. Defaulting them here would mean a second copy of the caller's
  /// own [_componentGroup] and of its policy-path call — two
  /// copies that can only ever agree until one of them changes, at which point
  /// a component would be told a different identity from the one the container
  /// asks the policy about. There is one caller; it has both values in hand.
  ///
  /// TomNodeScope propagation is handled at the container level (by
  /// `TomAclBuilder` / `TomContainerBase`) and is not duplicated here.
  Widget _wrapWithScope(
    Widget child,
    AclComponent comp,
    AclRow row, {
    required String? groupName,
    required String? fullPath,
  }) {
    return AclScope(
      containerId: widget.aclId,
      componentId: comp.id,
      rowId: row.id,
      groupName: groupName,
      fullIdPath: fullPath,
      child: child,
    );
  }

  /// Removes components whose children are `TomAuthorizable` resolving to
  /// [TomAuthState.none] — provided either the container default
  /// ([AclContainer.defaultHideUnauthorized]) or the per-component
  /// [AclComponent.hideUnauthorized] override says so.
  ///
  /// Elision rules — see "Hide on Authorization" (§26b) in
  /// `doc/acl_design_specification.md`, which is a different mechanism from
  /// the group visibility of §26 despite the adjacent numbering:
  ///
  ///   * A hidden component's own `gapBefore` (the gap between it and the
  ///     previous visible component) is **preserved** and handed to the
  ///     next visible component so the next visible component lands in
  ///     the hidden component's slot. The next visible component's own
  ///     `gapBefore` (the gap between the hidden component and itself —
  ///     "the gap after the hidden component") is **dropped**.
  ///   * Chain of hidden components: only the first hidden component's
  ///     gapBefore is carried forward; intermediate hidden components'
  ///     gapBefores are "gaps after a previous hidden component" and
  ///     get dropped.
  ///   * When every content component in a row is dropped, the whole
  ///     row is dropped as if it didn't exist — its own `gapBefore` is
  ///     carried to the next content row, which in turn has its own
  ///     `gapBefore` dropped (it was the "gap after the elided row").
  ///   * Gap rows and components without a `TomAuthorizable` child are
  ///     always preserved.
  ///
  /// This is not the only mechanism that removes an unauthorized element.
  /// Id'd rows and components are gated again at render time on their
  /// resolved policy path, regardless of `hideUnauthorized`; that gate runs
  /// too late to forward a gap, so it reclaims different space. Both are
  /// measured side by side in
  /// `test/advanced_container_layout/acl_auth_visibility_test.dart`.
  List<AclRow> _applyAuthHiding(List<AclRow> rows) {
    final containerDefault = widget.defaultHideUnauthorized;
    // Fast-path: nothing can ever be hidden.
    if (!containerDefault &&
        !rows.any((r) => r.components.any((c) => c.hideUnauthorized == true))) {
      return rows;
    }

    final out = <AclRow>[];
    bool inheritNextRowGap = false;
    double pendingRowGap = 0;

    for (final row in rows) {
      if (row.isGapRow) {
        // Gap rows are left untouched (they don't carry a gapBefore that
        // matters for this rule, and they're never auth-hidden).
        out.add(row);
        continue;
      }

      final keepers = <AclComponent>[];
      bool inheritNextGap = false;
      double pendingGap = 0;
      bool pendingGapIsDefault = false;
      for (final comp in row.components) {
        final hide = _shouldHide(comp, containerDefault);
        if (hide) {
          if (!inheritNextGap) {
            // First hidden in a chain — preserve its gapBefore for the
            // next visible component. Keep the default-flag so a
            // component that was using the row's breakpoint-resolved
            // default gap continues to use it instead of collapsing to
            // a literal 0.
            pendingGap = comp.gapBefore;
            pendingGapIsDefault = comp.gapBeforeIsDefault;
          }
          // Either way: the next visible component's own gapBefore is
          // "the gap after this hidden component" → drop it.
          inheritNextGap = true;
          continue;
        }
        if (inheritNextGap) {
          keepers.add(
            comp.copyWithGapBefore(
              pendingGap,
              gapBeforeIsDefault: pendingGapIsDefault,
            ),
          );
          inheritNextGap = false;
          pendingGap = 0;
          pendingGapIsDefault = false;
        } else {
          keepers.add(comp);
        }
      }

      if (keepers.isEmpty) {
        // Row has no surviving components — elide it completely. Its
        // own gapBefore carries forward the same way a hidden
        // component's gapBefore carries to the next visible component.
        if (!inheritNextRowGap) {
          pendingRowGap = row.gapBefore;
        }
        inheritNextRowGap = true;
        continue;
      }

      final rowGap = inheritNextRowGap ? pendingRowGap : row.gapBefore;
      inheritNextRowGap = false;
      pendingRowGap = 0;
      out.add(row.copyWith(components: keepers, gapBefore: rowGap));
    }
    return out;
  }

  /// Whether [comp]'s child should be elided by the hide-unauthorized
  /// pass: the child must be [TomAuthorizable], the effective flag has
  /// to be `true` (per-component override or container default), and the
  /// resolved auth state must be [TomAuthState.none].
  bool _shouldHide(AclComponent comp, bool containerDefault) {
    final effective = comp.hideUnauthorized ?? containerDefault;
    if (!effective) return false;
    final child = comp.child;
    if (child is TomAuthorizable) {
      return (child as TomAuthorizable).effectiveAuthState == TomAuthState.none;
    }
    return false;
  }

  // ── Content building ───────────────────────────────────────────────────────
}
