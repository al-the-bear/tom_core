part of 'acl_builder.dart';

/// Sizing a component and the container: the preferred, minimum and maximum
/// size hints, sizes taken from another component, the growth shorthands, and
/// the container's own size and scrolling.
extension AclBuilderSizing on AclBuilder {
  // ── Per-component sizing ───────────────────────────────────────────────────

  /// Sets a preferred size on the current component.
  ///
  /// Pass 0 for [width] or [height] to leave that dimension unchanged
  /// (preserving any previously set value, or defaulting to 0 / 0).
  AclBuilder setPSize(double width, [double height = 0]) {
    final component = _requireComponent('setPSize');
    final cur = component.preferredSize;
    component.preferredSize = Size(
      width == 0 ? (cur?.width ?? 0) : width,
      height == 0 ? (cur?.height ?? 0) : height,
    );
    return this;
  }

  /// Sets a minimum size on the current component.
  ///
  /// Pass 0 for [width] or [height] to leave that dimension unchanged
  /// (preserving any previously set value, or defaulting to 0 / 0).
  AclBuilder setMSize(double width, [double height = 0]) {
    final component = _requireComponent('setMSize');
    final cur = component.minimumSize;
    component.minimumSize = Size(
      width == 0 ? (cur?.width ?? 0) : width,
      height == 0 ? (cur?.height ?? 0) : height,
    );
    return this;
  }

  /// Sets a maximum size on the current component.
  ///
  /// Pass 0 for [width] or [height] to leave that dimension unchanged
  /// (preserving any previously set value, or leaving it **unconstrained**
  /// when none was set).
  ///
  /// The unset fallback is `double.infinity`, not 0 as it is on [setPSize]
  /// and [setMSize]. A preferred or minimum of 0 is no constraint, so those
  /// two can share the sentinel; a *maximum* of 0 means "no size at all", and
  /// the container turns it into `BoxConstraints(maxHeight: 0)` faithfully
  /// enough to collapse the child. `setXSize(200)` therefore caps the width
  /// and says nothing about the height, which is what it reads as.
  /// [setXWidthInChars] uses the same fallback for the same reason.
  AclBuilder setXSize(double width, [double height = 0]) {
    final component = _requireComponent('setXSize');
    final cur = component.maximumSize;
    component.maximumSize = Size(
      width == 0 ? (cur?.width ?? double.infinity) : width,
      height == 0 ? (cur?.height ?? double.infinity) : height,
    );
    return this;
  }

  /// Sets the **preferred** width of the current component using a character-count.
  /// [charWidth] is the width of one character in pixels (default 8).
  /// [height] is used as the preferred height when no height has been set yet.
  AclBuilder setPWidthInChars(
    int chars, {
    double charWidth = 8,
    double height = 40,
  }) {
    final component = _requireComponent('setPWidthInChars');
    final width = (chars * charWidth).clamp(0.0, double.maxFinite);
    final currentHeight = component.preferredSize?.height ?? height;
    component.preferredSize = Size(width, currentHeight);
    return this;
  }

  /// Sets the **minimum** width of the current component using a character-count.
  /// Preserves the existing minimum height (defaults to 0 if unset).
  AclBuilder setMWidthInChars(int chars, {double charWidth = 8}) {
    final component = _requireComponent('setMWidthInChars');
    final width = (chars * charWidth).clamp(0.0, double.maxFinite);
    final currentHeight = component.minimumSize?.height ?? 0.0;
    component.minimumSize = Size(width, currentHeight);
    return this;
  }

  /// Sets the **maximum** width of the current component using a character-count.
  /// Preserves the existing maximum height (defaults to infinity if unset).
  AclBuilder setXWidthInChars(int chars, {double charWidth = 8}) {
    final component = _requireComponent('setXWidthInChars');
    final width = (chars * charWidth).clamp(0.0, double.maxFinite);
    final currentHeight = component.maximumSize?.height ?? double.infinity;
    component.maximumSize = Size(width, currentHeight);
    return this;
  }

  // ── Per-component size references ──────────────────────────────────────────

  /// Links the current component's size to [reference]'s rendered size.
  ///
  /// [otherAttr] must carry at least one of [AclFlags.otherDimX] /
  /// [AclFlags.otherDimY]; only those bits are taken from it. Anything else
  /// would record a reference the layout never reads — a link that exists in
  /// the component and does nothing.
  AclBuilder setComp(Widget reference, int otherAttr) {
    final component = _requireComponent('setComp');
    final dimensions = otherAttr & AclFlags.otherDim;
    if (dimensions == 0) {
      throw ArgumentError.value(
        otherAttr,
        'otherAttr',
        'setComp needs AclFlags.otherDimX, AclFlags.otherDimY or '
            'AclFlags.otherDim — without one the reference is recorded and '
            'never read. Use sameWidthAs / sameHeightAs / sameSize instead.',
      );
    }
    final entry = _requireAppended(
      reference,
      'sameWidthAs / sameHeightAs / sameSize',
    );
    if (entry.row == _currentRow) {
      throw UnsupportedError(
        'AclBuilder: sameWidthAs / sameHeightAs / sameSize cannot reference a '
        'component in the same row. Move the reference to a different row, '
        'or use a cross-row anchor.',
      );
    }
    component.referenceKey = entry.key;
    component.flags |= dimensions;
    return this;
  }

  AclBuilder sameWidthAs(Widget reference) =>
      setComp(reference, AclFlags.otherDimX);

  AclBuilder sameHeightAs(Widget reference) =>
      setComp(reference, AclFlags.otherDimY);

  AclBuilder sameSize(Widget reference) =>
      setComp(reference, AclFlags.otherDim);

  // ── Container-level sizing ─────────────────────────────────────────────────

  AclBuilder setAclPSize(double width, double height) {
    _preferredContainerSize = Size(width, height);
    return this;
  }

  AclBuilder setAclMSize(double width, double height) {
    _minimumContainerSize = Size(width, height);
    return this;
  }

  AclBuilder setAclXSize(double width, double height) {
    _maximumContainerSize = Size(width, height);
    return this;
  }

  AclBuilder setAclScrollableX() {
    _scrollableX = true;
    return this;
  }

  AclBuilder setAclScrollableY() {
    _scrollableY = true;
    return this;
  }

  // ── Growth shorthands ─────────────────────────────────────────────────────

  /// Sets [AclFlags.expandX] on the component just appended.
  AclBuilder expandX() => setAttr(AclFlags.expandX);

  /// Sets [AclFlags.expandY] on the component just appended.
  AclBuilder expandY() => setAttr(AclFlags.expandY);

  /// Sets [AclFlags.expand] on the component just appended.
  AclBuilder expand() => setAttr(AclFlags.expand);
}
