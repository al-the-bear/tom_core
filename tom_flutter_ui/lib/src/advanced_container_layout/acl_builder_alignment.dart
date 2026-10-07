part of 'acl_builder.dart';

/// Aligning components: a component inside its row, a component to one in
/// another row or the same row, and a whole row within the container.
extension AclBuilderAlignment on AclBuilder {
  // ── Per-component vertical alignment ──────────────────────────────────────

  /// Overrides the vertical (cross-axis) alignment for the **current
  /// component only**, taking precedence over the row's and builder's
  /// default. Components only have one axis of alignment inside a row —
  /// horizontal placement is a whole-row concern — so a single method
  /// with an [AclRowCrossAlignment] argument covers every case.
  AclBuilder setVerticalAlignment(AclRowCrossAlignment align) {
    final component = _requireComponent('setVerticalAlignment');
    if (component.alignYToKey != null) {
      throw UnsupportedError(
        'AclBuilder.setVerticalAlignment() cannot be combined with an '
        'alignY* method on the same component — alignY* overrides the '
        'row cross-alignment.',
      );
    }
    component.rowCrossAlignment = align;
    component.rowCrossAlignmentSet = true;
    return this;
  }

  // ── Cross-row horizontal alignment ────────────────────────────────────────

  AclBuilder alignLeftToLeft(Widget reference, {double gap = 0}) =>
      _setHorizontalAlignment(
        reference: reference,
        selfPoint: AclAxisPointX.left,
        referencePoint: AclAxisPointX.left,
        gap: gap,
      );

  AclBuilder alignLeftToCenter(Widget reference, {double gap = 0}) =>
      _setHorizontalAlignment(
        reference: reference,
        selfPoint: AclAxisPointX.left,
        referencePoint: AclAxisPointX.center,
        gap: gap,
      );

  AclBuilder alignLeftToRight(Widget reference, {double gap = 0}) =>
      _setHorizontalAlignment(
        reference: reference,
        selfPoint: AclAxisPointX.left,
        referencePoint: AclAxisPointX.right,
        gap: gap,
      );

  AclBuilder alignCenterToLeft(Widget reference, {double gap = 0}) =>
      _setHorizontalAlignment(
        reference: reference,
        selfPoint: AclAxisPointX.center,
        referencePoint: AclAxisPointX.left,
        gap: gap,
      );

  AclBuilder alignCenterToCenter(Widget reference, {double gap = 0}) =>
      _setHorizontalAlignment(
        reference: reference,
        selfPoint: AclAxisPointX.center,
        referencePoint: AclAxisPointX.center,
        gap: gap,
      );

  AclBuilder alignCenterToRight(Widget reference, {double gap = 0}) =>
      _setHorizontalAlignment(
        reference: reference,
        selfPoint: AclAxisPointX.center,
        referencePoint: AclAxisPointX.right,
        gap: gap,
      );

  AclBuilder alignRightToLeft(Widget reference, {double gap = 0}) =>
      _setHorizontalAlignment(
        reference: reference,
        selfPoint: AclAxisPointX.right,
        referencePoint: AclAxisPointX.left,
        gap: gap,
      );

  AclBuilder alignRightToCenter(Widget reference, {double gap = 0}) =>
      _setHorizontalAlignment(
        reference: reference,
        selfPoint: AclAxisPointX.right,
        referencePoint: AclAxisPointX.center,
        gap: gap,
      );

  AclBuilder alignRightToRight(Widget reference, {double gap = 0}) =>
      _setHorizontalAlignment(
        reference: reference,
        selfPoint: AclAxisPointX.right,
        referencePoint: AclAxisPointX.right,
        gap: gap,
      );

  // ── Same-row vertical alignment ───────────────────────────────────────────

  AclBuilder alignTopToTop(Widget reference, {double gap = 0}) =>
      _setVerticalAlignment(
        reference: reference,
        selfPoint: AclAxisPointY.top,
        referencePoint: AclAxisPointY.top,
        gap: gap,
      );

  AclBuilder alignTopToMiddle(Widget reference, {double gap = 0}) =>
      _setVerticalAlignment(
        reference: reference,
        selfPoint: AclAxisPointY.top,
        referencePoint: AclAxisPointY.center,
        gap: gap,
      );

  AclBuilder alignTopToBottom(Widget reference, {double gap = 0}) =>
      _setVerticalAlignment(
        reference: reference,
        selfPoint: AclAxisPointY.top,
        referencePoint: AclAxisPointY.bottom,
        gap: gap,
      );

  AclBuilder alignMiddleToTop(Widget reference, {double gap = 0}) =>
      _setVerticalAlignment(
        reference: reference,
        selfPoint: AclAxisPointY.center,
        referencePoint: AclAxisPointY.top,
        gap: gap,
      );

  AclBuilder alignMiddleToMiddle(Widget reference, {double gap = 0}) =>
      _setVerticalAlignment(
        reference: reference,
        selfPoint: AclAxisPointY.center,
        referencePoint: AclAxisPointY.center,
        gap: gap,
      );

  AclBuilder alignMiddleToBottom(Widget reference, {double gap = 0}) =>
      _setVerticalAlignment(
        reference: reference,
        selfPoint: AclAxisPointY.center,
        referencePoint: AclAxisPointY.bottom,
        gap: gap,
      );

  AclBuilder alignBottomToTop(Widget reference, {double gap = 0}) =>
      _setVerticalAlignment(
        reference: reference,
        selfPoint: AclAxisPointY.bottom,
        referencePoint: AclAxisPointY.top,
        gap: gap,
      );

  AclBuilder alignBottomToMiddle(Widget reference, {double gap = 0}) =>
      _setVerticalAlignment(
        reference: reference,
        selfPoint: AclAxisPointY.bottom,
        referencePoint: AclAxisPointY.center,
        gap: gap,
      );

  AclBuilder alignBottomToBottom(Widget reference, {double gap = 0}) =>
      _setVerticalAlignment(
        reference: reference,
        selfPoint: AclAxisPointY.bottom,
        referencePoint: AclAxisPointY.bottom,
        gap: gap,
      );

  // ── Row-level alignment ───────────────────────────────────────────────────
  //
  // Two orthogonal axes:
  //   * Horizontal — where components sit along the row's main axis
  //     (RowAlignment.left / center / right). Set via
  //     [setRowHorizontalAlignment] or the [setRowAlignLeft] / Center /
  //     Right shortcuts.
  //   * Vertical — where components sit along the row's cross axis
  //     (AclRowCrossAlignment.top / center / bottom). Set via
  //     [setRowVerticalAlignment] or the [setRowAlignTop] / Middle /
  //     Bottom shortcuts.
  //
  // Components inherit the row's vertical alignment unless they opt out
  // via [setVerticalAlignment]. The row itself falls back to the
  // builder-wide default (see [setAclDefaultRowVerticalAlignment] and
  // [setAclDefaultRowHorizontalAlignment]).

  /// Horizontal main-axis placement for the **current row only**.
  AclBuilder setRowHorizontalAlignment(RowAlignment align) {
    _currentRow.alignment = align;
    _currentRow.alignmentSet = true;
    return this;
  }

  /// Vertical cross-axis placement for the **current row only**.
  ///
  /// Components appended to this row — before OR after this call —
  /// inherit the row's alignment unless they explicitly override via
  /// [setVerticalAlignment]. Without this call the row inherits the
  /// builder-wide default (see [setAclDefaultRowVerticalAlignment]).
  AclBuilder setRowVerticalAlignment(AclRowCrossAlignment align) {
    _currentRow.rowCrossAlignment = align;
    // Retroactively propagate to components in the current row that
    // haven't set their own alignment. New components appended after
    // this call inherit via [_onComponentAppended] (see append()).
    for (final comp in _currentRow.components) {
      if (!comp.rowCrossAlignmentSet) {
        comp.rowCrossAlignment = align;
      }
    }
    return this;
  }

  // ── Row-level horizontal alignment shortcuts ──
  AclBuilder setRowAlignLeft() => setRowHorizontalAlignment(RowAlignment.left);
  AclBuilder setRowAlignCenter() =>
      setRowHorizontalAlignment(RowAlignment.center);
  AclBuilder setRowAlignRight() =>
      setRowHorizontalAlignment(RowAlignment.right);

  // ── Row-level vertical alignment shortcuts ──
  AclBuilder setRowAlignTop() =>
      setRowVerticalAlignment(AclRowCrossAlignment.top);
  AclBuilder setRowAlignMiddle() =>
      setRowVerticalAlignment(AclRowCrossAlignment.center);
  AclBuilder setRowAlignBottom() =>
      setRowVerticalAlignment(AclRowCrossAlignment.bottom);

  AclBuilder _setHorizontalAlignment({
    required Widget reference,
    required AclAxisPointX selfPoint,
    required AclAxisPointX referencePoint,
    required double gap,
  }) {
    final component = _requireComponent('alignX*');
    final entry = _requireAppended(reference, 'alignX*');
    if (entry.row == _currentRow) {
      throw UnsupportedError(
        'AclBuilder: alignX* same-row reference — the reference widget '
        'must be in a different row. Use alignY* for same-row vertical alignment.',
      );
    }
    component.alignXToKey = entry.key;
    component.alignXFrom = selfPoint;
    component.alignXTo = referencePoint;
    component.alignXGap = gap;
    return this;
  }

  AclBuilder _setVerticalAlignment({
    required Widget reference,
    required AclAxisPointY selfPoint,
    required AclAxisPointY referencePoint,
    required double gap,
  }) {
    final component = _requireComponent('alignY*');
    if (component.rowCrossAlignmentSet) {
      throw UnsupportedError(
        'AclBuilder: alignY* cannot be combined with setVerticalAlignment() '
        'on the same component — remove the setVerticalAlignment() call.',
      );
    }
    final entry = _requireAppended(reference, 'alignY*');
    if (entry.row != _currentRow) {
      throw UnsupportedError(
        'AclBuilder: alignY* cross-row reference — the reference widget '
        'must be in the same row. Use alignX* for cross-row horizontal alignment.',
      );
    }
    component.alignYToKey = entry.key;
    component.alignYFrom = selfPoint;
    component.alignYTo = referencePoint;
    component.alignYGap = gap;
    return this;
  }
}
