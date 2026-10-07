part of 'acl_builder.dart';

class _ComponentData {
  Widget child;
  int flags;
  double gapBefore;
  bool gapBeforeIsDefault;
  double gapWeight;
  Size? preferredSize;

  /// Whether [preferredSize]'s width was fabricated by
  /// [_finalizeCurrentComponent] rather than declared by the author.
  bool preferredWidthIsDefault = false;
  Size? minimumSize;
  Size? maximumSize;
  Key? referenceKey;
  Key? alignXToKey;
  AclAxisPointX? alignXFrom;
  AclAxisPointX? alignXTo;
  double alignXGap = 0;
  Key? alignYToKey;
  AclAxisPointY? alignYFrom;
  AclAxisPointY? alignYTo;
  double alignYGap = 0;
  AclRowCrossAlignment rowCrossAlignment = AclRowCrossAlignment.top;
  bool rowCrossAlignmentSet = false;
  Key? componentKey;
  String? id;
  String? group;
  bool inlineVariant = false;
  AclVariantDetector? variantDetector;
  bool? hideUnauthorized;

  _ComponentData({
    required this.child,
    this.flags = 0,
    this.gapBefore = 0,
    this.gapBeforeIsDefault = false,
    this.gapWeight = 1.0,
    this.componentKey,
  });

  AclComponent toComponent() {
    return AclComponent(
      child: child,
      flags: flags,
      gapBefore: gapBefore,
      gapBeforeIsDefault: gapBeforeIsDefault,
      gapWeight: gapWeight,
      preferredSize: preferredSize,
      preferredWidthIsDefault: preferredWidthIsDefault,
      minimumSize: minimumSize,
      maximumSize: maximumSize,
      referenceKey: referenceKey,
      alignXToKey: alignXToKey,
      alignXFrom: alignXFrom,
      alignXTo: alignXTo,
      alignXGap: alignXGap,
      alignYToKey: alignYToKey,
      alignYFrom: alignYFrom,
      alignYTo: alignYTo,
      alignYGap: alignYGap,
      rowCrossAlignment: rowCrossAlignment,
      componentKey: componentKey,
      id: id,
      group: group,
      inlineVariant: inlineVariant,
      variantDetector: variantDetector,
      hideUnauthorized: hideUnauthorized,
    );
  }
}

class _RowData {
  List<_ComponentData> components = [];
  RowAlignment alignment = RowAlignment.left;

  /// Whether [alignment] was set explicitly via `setRowHorizontalAlignment`
  /// (as opposed to inherited from the builder-wide default at row creation).
  /// Mirrors the vertical axis' `rowCrossAlignment == null` "not set yet"
  /// signal so a later default change can apply retroactively without
  /// clobbering explicit per-row overrides.
  ///
  /// [alignment] cannot carry that signal itself: it is non-nullable and every
  /// row starts at the builder default, so "still at the default" and "was
  /// explicitly set to the same value as the default" are indistinguishable
  /// without this flag. `setAclDefaultRowHorizontalAlignment` reads it to
  /// decide which already-created rows it may rewrite.
  bool alignmentSet = false;
  double gapBefore = 0;
  bool isGapRow = false;
  double gapRowWeight = 1.0;
  AclSeparator? separator;
  double gapRowMinSize = 0;
  String? id;
  String? group;
  bool idScope = false;
  List<AclRowBreakpoint> breakpoints = [];

  /// Row-level height (null = inherit builder default).
  double? height;
  bool heightIsExplicit = false;
  List<(double, double?)> heightBpOverrides = const [];

  /// Per-row cross-axis alignment override. `null` means "use the
  /// builder's default" (set via `setAclDefaultRowVerticalAlignment`).
  AclRowCrossAlignment? rowCrossAlignment;

  AclRow toRow({
    required double defaultAppendGap,
    required List<(double, double)> defaultAppendGapBpOverrides,
    required double? fallbackHeight,
    required List<(double, double?)> fallbackHeightBpOverrides,
    required AclRowCrossAlignment defaultRowCrossAlignment,
  }) {
    return AclRow(
      components: components.map((c) => c.toComponent()).toList(),
      alignment: alignment,
      gapBefore: gapBefore,
      isGapRow: isGapRow,
      gapRowWeight: gapRowWeight,
      separator: separator,
      gapRowMinSize: gapRowMinSize,
      id: id,
      group: group,
      idScope: idScope,
      breakpoints: breakpoints,
      height: heightIsExplicit ? height : fallbackHeight,
      heightBpOverrides: heightIsExplicit
          ? heightBpOverrides
          : fallbackHeightBpOverrides,
      defaultAppendGap: defaultAppendGap,
      defaultAppendGapBpOverrides: defaultAppendGapBpOverrides,
      // Per-row override beats the builder-wide default.
      defaultRowCrossAlignment: rowCrossAlignment ?? defaultRowCrossAlignment,
    );
  }
}
