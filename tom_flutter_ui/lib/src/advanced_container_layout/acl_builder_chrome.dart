part of 'acl_builder.dart';

/// The container's defaults and its chrome: default flags, gaps, row heights
/// and alignments, the unauthorized-component policy, border, padding,
/// background and title.
extension AclBuilderChrome on AclBuilder {
  // ── Container-level decoration ─────────────────────────────────────────────

  /// Replaces the default [AclFlags] register applied to every subsequent
  /// [append]. The built-in default is 0 — no flags.
  ///
  /// Prefer [setAclExpandXDefault] for the common single-flag case; it adds
  /// or removes one flag rather than replacing the whole register.
  AclBuilder setAclDefaultFlags(int flags) {
    _defaultFlags = flags;
    return this;
  }

  int get defaultFlags => _defaultFlags;

  /// Sets the default expand-X behaviour for newly appended components.
  ///
  /// When [enabled] is `true`, [AclFlags.expandX] is added to the default
  /// flags so every subsequent [append] call gets expandX automatically.
  /// When `false`, the flag is removed from the defaults.
  ///
  /// Individual components can still override via [clearAttr]/[setAttr].
  AclBuilder setAclExpandXDefault(bool enabled) {
    if (enabled) {
      _defaultFlags |= AclFlags.expandX;
    } else {
      _defaultFlags &= ~AclFlags.expandX;
    }
    return this;
  }

  /// Sets the default horizontal gap inserted before every appended
  /// component of every row, including the first component.
  ///
  /// Applies only when the individual [append] call does not specify a
  /// non-zero `dist`. Pass [gap] = 0 to disable (the built-in default is 8).
  ///
  /// [gapBpOverrides] is a list of `(minWidth, gap)` pairs; at render time
  /// the pair with the highest `minWidth <= availableWidth` wins.
  AclBuilder setAclDefaultAppendGap(
    double gap, [
    List<(double, double)> gapBpOverrides = const [],
  ]) {
    _defaultAppendGap = gap;
    _defaultAppendGapBpOverrides = gapBpOverrides;
    return this;
  }

  /// Sets the builder-wide default row height (null = intrinsic).
  ///
  /// Applied to every row that does not set its own height via
  /// [setRowHeight] or [newRow]'s `height:` parameter.
  /// [heightBpOverrides] is a list of `(minWidth, height?)` pairs.
  AclBuilder setAclDefaultRowHeight(
    double? height, [
    List<(double, double?)> heightBpOverrides = const [],
  ]) {
    _defaultRowHeight = height;
    _defaultRowHeightBpOverrides = heightBpOverrides;
    return this;
  }

  /// Sets the height on the current (most-recently-started) row.
  ///
  /// [heightBpOverrides] follows the same `(minWidth, height?)` shape as
  /// [setAclDefaultRowHeight]. Passing `null` height with an empty overrides
  /// list clears the row-level override (the builder default applies).
  AclBuilder setRowHeight(
    double? height, [
    List<(double, double?)> heightBpOverrides = const [],
  ]) {
    _currentRow.height = height;
    _currentRow.heightBpOverrides = heightBpOverrides;
    _currentRow.heightIsExplicit = true;
    return this;
  }

  /// Sets the default vertical gap (in pixels) inserted before each new
  /// content row started with [newRow].
  ///
  /// Only applies when the individual [newRow] call does not specify a
  /// non-zero `dist`. Pass 0 to disable (the built-in default is 8).
  AclBuilder setAclDefaultRowGap(int pixels) {
    _defaultRowGap = pixels.toDouble();
    return this;
  }

  /// Sets the builder-wide default for the hide-when-unauthorized
  /// behaviour. When `true`, every appended component whose child
  /// implements [TomAuthorizable] and currently evaluates to
  /// [TomAuthState.none] is **dropped from the row** at build time;
  /// the `gapBefore` of the component that follows it is also dropped
  /// so the next visible component takes the hidden component's slot.
  /// When a row is left with no components it is dropped in turn, along
  /// with the next row's `gapBefore`.
  ///
  /// The default is `false`, which switches this pass off. That does **not**
  /// leave unauthorized elements visible: a row or component carrying an `id`
  /// is separately gated at render time on `TomAuthorization.resolveAuth` of
  /// its policy path, and that gate never consults this flag. It also runs too
  /// late to move a gap, so its arithmetic comes out the other way round — a
  /// denied component keeps **both** adjacent gaps, and a denied row loses its
  /// own. See "Not this mechanism: the id-based policy gates" in
  /// `doc/acl_design_specification.md` §26b, and
  /// `test/advanced_container_layout/acl_auth_visibility_test.dart` for the
  /// measured numbers.
  ///
  /// With this pass off and no id to gate on, a component renders whatever its
  /// own self-shrink-on-`none` path produces, inside its preserved gap.
  ///
  /// Override per-component with [setHideUnauthorized].
  AclBuilder setAclDefaultHideUnauthorized(bool value) {
    _defaultHideUnauthorized = value;
    return this;
  }

  /// Overrides the container's hide-when-unauthorized default for the
  /// most recently appended component. Pass `null` to clear the override
  /// and fall back to the container default.
  ///
  /// See [setAclDefaultHideUnauthorized] for the full semantics.
  AclBuilder setHideUnauthorized(bool? value) {
    _requireComponent('setHideUnauthorized').hideUnauthorized = value;
    return this;
  }

  /// Builder-wide default for the **vertical** cross-axis placement of
  /// every row. Individual rows override via [setRowVerticalAlignment];
  /// individual components override via [setVerticalAlignment].
  ///
  /// The factory default is [AclRowCrossAlignment.top] — chosen so that
  /// fields whose height grows (e.g. when an error message appears
  /// below the input) do not drag their neighbours down off the row's
  /// top edge.
  AclBuilder setAclDefaultRowVerticalAlignment(AclRowCrossAlignment alignment) {
    _defaultRowVerticalAlignment = alignment;
    // Retroactively apply to rows and components that haven't set their
    // own alignment — keeps call order flexible.
    for (final row in _rows) {
      if (row.rowCrossAlignment == null) {
        for (final comp in row.components) {
          if (!comp.rowCrossAlignmentSet) {
            comp.rowCrossAlignment = alignment;
          }
        }
      }
    }
    return this;
  }

  /// Builder-wide default for the **horizontal** main-axis placement of
  /// every row. Individual rows override via [setRowHorizontalAlignment]
  /// or the Left/Center/Right shortcuts.
  ///
  /// The factory default is [AclRowAlignment.left].
  AclBuilder setAclDefaultRowHorizontalAlignment(AclRowAlignment alignment) {
    _defaultRowHorizontalAlignment = alignment;
    // Retroactively apply to every row that hasn't set its own alignment —
    // including the eagerly-created first row — so call order stays flexible.
    // Rows that called setRowHorizontalAlignment keep their own value.
    for (final row in _rows) {
      if (!row.alignmentSet) {
        row.alignment = alignment;
      }
    }
    return this;
  }

  /// Sets a default minimum size for components that do not have an explicit
  /// minimum size ([setMSize] / [setMWidthInChars]).
  ///
  /// There is no built-in default: unless this is called, a component without
  /// an explicit minimum keeps a null minimum size.
  ///
  /// [width] and [height] are stored verbatim, including zeros, and a later
  /// call replaces **both** dimensions — there is no per-axis fallback and no
  /// previous value to fall back on. A 0 therefore means "a minimum of 0 on
  /// that axis", which the layout cannot tell apart from no minimum at all;
  /// that is what makes storing it harmless, not a special case that skips it.
  /// Contrast [setMSize], which does leave a dimension alone on a 0, because a
  /// component it targets already has a minimum to leave alone.
  ///
  /// **Note:** setting a minimum that is smaller than the preferred size has no
  /// visible effect — the preferred size already acts as the floor. Setting a
  /// minimum that is *larger* than the preferred size in combination with
  /// [expandX] components creates a "grow up to preferred, then distribute
  /// remainder to expandX" behaviour — see "Row Sizing — Three Phases" (§6)
  /// in `doc/acl_design_specification.md`.
  AclBuilder setAclDefaultUnknownMinimumSize(
    double width, [
    double height = 0,
  ]) {
    _defaultUnknownMinimumSize = Size(width, height);
    return this;
  }

  /// Sets a default preferred size for components that do not have an explicit
  /// preferred size ([setPSize] / [setPWidthInChars]).
  ///
  /// Replaces the built-in default of 150 × 0.
  ///
  /// A 0 [width] falls back to [defaultPreferredWidth] — the *factory* 150,
  /// not whatever an earlier call to this setter passed. [height] has no such
  /// fallback: it is stored verbatim, and 0 leaves the height unconstrained
  /// because 0 already is the built-in height.
  ///
  /// This is the only 0-means-fall-back among the builder-wide setters;
  /// [setAclDefaultUnknownMinimumSize] stores its zeros, and the two gap
  /// setters read 0 as "off".
  AclBuilder setAclDefaultUnknownPreferredSize(
    double width, [
    double height = 0,
  ]) {
    _defaultUnknownPreferredSize = Size(width, height);
    return this;
  }

  AclBuilder setAclBorderStyle(AclBorderStyle style) {
    _borderStyle = style;
    return this;
  }

  AclBuilder setAclBorderInsets(EdgeInsetsGeometry insets) {
    _borderStyle = _borderStyle.copyWith(borderInsets: insets);
    return this;
  }

  AclBuilder setAclFocusedBorderStyle(AclBorderStyle style) {
    _focusedBorderStyle = style;
    return this;
  }

  AclBuilder setAclPadding(EdgeInsetsGeometry padding) {
    _padding = padding;
    return this;
  }

  AclBuilder setAclPaddingPx(
    double left,
    double top,
    double right,
    double bottom,
  ) {
    _padding = EdgeInsets.fromLTRB(left, top, right, bottom);
    return this;
  }

  AclBuilder setAclPaddingTop(double value) {
    final resolved = _padding.resolve(TextDirection.ltr);
    _padding = EdgeInsets.fromLTRB(
      resolved.left,
      value,
      resolved.right,
      resolved.bottom,
    );
    return this;
  }

  AclBuilder setAclPaddingBottom(double value) {
    final resolved = _padding.resolve(TextDirection.ltr);
    _padding = EdgeInsets.fromLTRB(
      resolved.left,
      resolved.top,
      resolved.right,
      value,
    );
    return this;
  }

  AclBuilder setAclPaddingLeft(double value) {
    final resolved = _padding.resolve(TextDirection.ltr);
    _padding = EdgeInsets.fromLTRB(
      value,
      resolved.top,
      resolved.right,
      resolved.bottom,
    );
    return this;
  }

  AclBuilder setAclPaddingRight(double value) {
    final resolved = _padding.resolve(TextDirection.ltr);
    _padding = EdgeInsets.fromLTRB(
      resolved.left,
      resolved.top,
      value,
      resolved.bottom,
    );
    return this;
  }

  AclBuilder setAclBackgroundColor(Color color) {
    _backgroundColor = color;
    return this;
  }

  AclBuilder setAclTitle(String? title) {
    _title = title;
    return this;
  }

  AclBuilder setAclTitleWidget(Widget? widget) {
    _titleWidget = widget;
    return this;
  }

  AclBuilder setAclTitleStyle(TextStyle style) {
    _titleStyle = style;
    return this;
  }

  AclBuilder setAclTitlePosition(AclTitlePosition position) {
    _titlePosition = position;
    return this;
  }

  AclBuilder setAclTitleBorderAlign(AclTitleBorderAlign align) {
    _titleBorderAlign = align;
    return this;
  }

  AclBuilder setAclTitleVerticalOffset(double offset) {
    _titleVerticalOffset = offset;
    return this;
  }
}
