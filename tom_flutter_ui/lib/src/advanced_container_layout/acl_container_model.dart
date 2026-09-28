/// The immutable layout model: one cell, one row, and the breakpoint
/// resolvers that read them at a width.
///
/// This is the half of the unit that can be computed and asserted without a
/// widget tree, which is why it is worth having on its own.
///
/// See `acl_container.dart` for why these are parts rather than libraries.
part of 'acl_container.dart';

class AclComponent {
  final Widget child;
  final int flags;
  final double gapBefore;

  /// `true` when [gapBefore] should be replaced at render time by the
  /// breakpoint-resolved default append gap carried on the parent [AclRow].
  /// Set by the builder when the caller did not pass an explicit `dist`.
  final bool gapBeforeIsDefault;

  /// Relative weight used when this is a gap slot (isGap == true).
  final double gapWeight;

  final Size? preferredSize;

  /// `true` when [preferredSize]'s width was not declared by the author but
  /// fabricated by `AclBuilder` from [AclBuilder.defaultPreferredWidth].
  ///
  /// A declared width is honoured literally. A defaulted one is only a
  /// **floor**: the container measures the child's natural width and widens the
  /// component when its content needs more, so a forgotten size hint produces a
  /// component that fits rather than a `RenderFlex` overflow. When even the
  /// widened component does not fit the row, the content is clipped — never
  /// overflowed — and keeps the width it laid out at.
  final bool preferredWidthIsDefault;
  final Size? minimumSize;
  final Size? maximumSize;
  final Key? referenceKey;
  final Key? alignXToKey;
  final AclAxisPointX? alignXFrom;
  final AclAxisPointX? alignXTo;
  final double alignXGap;
  final Key? alignYToKey;
  final AclAxisPointY? alignYFrom;
  final AclAxisPointY? alignYTo;
  final double alignYGap;
  final AclRowCrossAlignment rowCrossAlignment;
  final Key? componentKey;

  /// Optional identifier for this component. Joined with the ids of enclosing
  /// identity rows and containers to form the path used for resource lookup
  /// and authorization.
  ///
  /// See "Container IDs" (§24) in `doc/acl_design_specification.md`.
  final String? id;

  /// Optional group name this component belongs to. Membership is what a
  /// [AclGroupVisibilityController] acts on when it shows, hides or disables
  /// a group.
  ///
  /// See "Groups" (§25) in `doc/acl_design_specification.md`.
  final String? group;

  /// Whether this component is inside an inline variant block, and so is
  /// subject to [variantDetector] rather than being unconditionally kept.
  ///
  /// See "Inline Component Variants" (§29) in
  /// `doc/acl_design_specification.md`.
  final bool inlineVariant;

  /// Detector function that determines whether this variant is active.
  /// Null for the default variant (shown when no other detector matches).
  ///
  /// See "Inline Component Variants" (§29) in
  /// `doc/acl_design_specification.md`.
  final AclVariantDetector? variantDetector;

  /// Per-component override for the container's default hide-when-
  /// unauthorized behaviour. `null` → inherit the container's
  /// `defaultHideUnauthorized` flag. `true` → if this component's child is
  /// a [TomAuthorizable] resolving to [TomAuthState.none], remove it from
  /// the row entirely; the **following** component's `gapBefore` is
  /// dropped too so the next visible component slides into the slot.
  /// `false` → never auto-remove.
  final bool? hideUnauthorized;

  const AclComponent({
    required this.child,
    this.flags = 0,
    this.gapBefore = 0,
    this.gapBeforeIsDefault = false,
    this.gapWeight = 1.0,
    this.preferredSize,
    this.preferredWidthIsDefault = false,
    this.minimumSize,
    this.maximumSize,
    this.referenceKey,
    this.alignXToKey,
    this.alignXFrom,
    this.alignXTo,
    this.alignXGap = 0,
    this.alignYToKey,
    this.alignYFrom,
    this.alignYTo,
    this.alignYGap = 0,
    this.rowCrossAlignment = AclRowCrossAlignment.top,
    this.componentKey,
    this.id,
    this.group,
    this.inlineVariant = false,
    this.variantDetector,
    this.hideUnauthorized,
  });

  /// Returns a copy with the named fields replaced; omitted arguments keep
  /// their current value.
  ///
  /// Because every argument uses `?? this.x`, a nullable field cannot be
  /// *cleared* through this method — passing `null` means "leave it alone".
  /// No caller needs clearing, and the alternative (a sentinel per nullable
  /// field) would cost more than it buys on a 25-field class.
  ///
  /// Every declared field is covered, and
  /// `test/advanced_container_layout/acl_component_copy_with_test.dart` checks
  /// that against the constructor rather than taking it on trust — a field
  /// left out of the list below would not fail to compile, it would silently
  /// revert to its default on every copy.
  AclComponent copyWith({
    Widget? child,
    int? flags,
    double? gapBefore,
    bool? gapBeforeIsDefault,
    double? gapWeight,
    Size? preferredSize,
    bool? preferredWidthIsDefault,
    Size? minimumSize,
    Size? maximumSize,
    Key? referenceKey,
    Key? alignXToKey,
    AclAxisPointX? alignXFrom,
    AclAxisPointX? alignXTo,
    double? alignXGap,
    Key? alignYToKey,
    AclAxisPointY? alignYFrom,
    AclAxisPointY? alignYTo,
    double? alignYGap,
    AclRowCrossAlignment? rowCrossAlignment,
    Key? componentKey,
    String? id,
    String? group,
    bool? inlineVariant,
    AclVariantDetector? variantDetector,
    bool? hideUnauthorized,
  }) {
    return AclComponent(
      child: child ?? this.child,
      flags: flags ?? this.flags,
      gapBefore: gapBefore ?? this.gapBefore,
      gapBeforeIsDefault: gapBeforeIsDefault ?? this.gapBeforeIsDefault,
      gapWeight: gapWeight ?? this.gapWeight,
      preferredSize: preferredSize ?? this.preferredSize,
      preferredWidthIsDefault:
          preferredWidthIsDefault ?? this.preferredWidthIsDefault,
      minimumSize: minimumSize ?? this.minimumSize,
      maximumSize: maximumSize ?? this.maximumSize,
      referenceKey: referenceKey ?? this.referenceKey,
      alignXToKey: alignXToKey ?? this.alignXToKey,
      alignXFrom: alignXFrom ?? this.alignXFrom,
      alignXTo: alignXTo ?? this.alignXTo,
      alignXGap: alignXGap ?? this.alignXGap,
      alignYToKey: alignYToKey ?? this.alignYToKey,
      alignYFrom: alignYFrom ?? this.alignYFrom,
      alignYTo: alignYTo ?? this.alignYTo,
      alignYGap: alignYGap ?? this.alignYGap,
      rowCrossAlignment: rowCrossAlignment ?? this.rowCrossAlignment,
      componentKey: componentKey ?? this.componentKey,
      id: id ?? this.id,
      group: group ?? this.group,
      inlineVariant: inlineVariant ?? this.inlineVariant,
      variantDetector: variantDetector ?? this.variantDetector,
      hideUnauthorized: hideUnauthorized ?? this.hideUnauthorized,
    );
  }

  /// Returns a copy with `gapBefore` / `gapBeforeIsDefault` replaced. Used
  /// by the hide-unauthorized pass when it carries a hidden component's
  /// effective gap onto the next visible component — the default-flag
  /// needs to travel with the literal value so the row's breakpoint-
  /// resolved default still applies at render time.
  AclComponent copyWithGapBefore(
    double newGap, {
    bool gapBeforeIsDefault = false,
  }) {
    return copyWith(gapBefore: newGap, gapBeforeIsDefault: gapBeforeIsDefault);
  }

  bool get expandX => (flags & AclFlags.expandX) != 0;
  bool get expandY => (flags & AclFlags.expandY) != 0;

  /// `true` when this component is an elastic spacer rather than content.
  ///
  /// A gap slot's [child] is never built — the container replaces it with a
  /// `Spacer` sized from [gapWeight]. This is how the layout passes tell a
  /// spacer from a widget, so it reads as a plain component everywhere else in
  /// the model. `AclBuilder.gap()` is what produces one.
  bool get isGap => (flags & AclFlags.gapElement) != 0;

  bool get useOtherDimX => (flags & AclFlags.otherDimX) != 0;
  bool get useOtherDimY => (flags & AclFlags.otherDimY) != 0;
}

// ── AclRow ───────────────────────────────────────────────────────────────────

class AclRow {
  final List<AclComponent> components;
  final RowAlignment alignment;

  /// Fixed pixel gap before this row.
  final double gapBefore;

  /// When true this row is an elastic vertical spacer, not a content row.
  final bool isGapRow;

  /// Relative weight for vertical space distribution among gap rows.
  final double gapRowWeight;

  /// Optional separator drawn inside the gap row area.
  final AclSeparator? separator;

  /// Minimum pixel height for this gap row when a layout with [expandY]
  /// components is present. Defaults to 0 (pure spacing gaps collapse; a
  /// [separator] gapRow always gets at least 9 px regardless of this value).
  final double gapRowMinSize;

  /// Optional identifier for this row. Whether it reaches descendant paths
  /// depends on [idScope].
  ///
  /// See "Container IDs" (§24) in `doc/acl_design_specification.md`.
  final String? id;

  /// Optional group name this row belongs to, letting a
  /// [AclGroupVisibilityController] act on the row as a unit.
  ///
  /// See "Groups" (§25) in `doc/acl_design_specification.md`.
  final String? group;

  /// Whether this row contributes its ID to descendant paths.
  ///
  /// - `true` — identity row: ID appears in descendant component paths.
  /// - `false` — layout row (default): ID is for own resources/auth only.
  final bool idScope;

  /// Row breakpoints for responsive splitting: below a given width this row
  /// is broken into several, each fragment keeping the original row's own
  /// settings because it is still the same logical row.
  ///
  /// See "Row Breakpoints" (§28) in `doc/acl_design_specification.md`.
  final List<AclRowBreakpoint> breakpoints;

  /// Fixed pixel height for this content row (null = intrinsic). Resolved at
  /// render time via [heightBpOverrides] against the current available width.
  final double? height;

  /// `(minWidth, height?)` pairs overriding [height] above certain widths.
  final List<(double, double?)> heightBpOverrides;

  /// Default horizontal gap for components whose `gapBeforeIsDefault` is true.
  /// Snapshotted from the builder at [AclRow] construction time.
  final double defaultAppendGap;

  /// `(minWidth, gap)` pairs overriding [defaultAppendGap] above certain widths.
  final List<(double, double)> defaultAppendGapBpOverrides;

  /// Vertical cross-axis alignment applied to the Row widget itself.
  /// Snapshotted at row construction via the resolution chain per-row
  /// override (setRowVerticalAlignment) → builder-wide default
  /// (setAclDefaultRowVerticalAlignment). Individual components can
  /// still request a different placement within their own cell via
  /// [AclBuilder.setVerticalAlignment] (handled per-cell by
  /// `_wrapWithRowCrossAlignment`).
  final AclRowCrossAlignment defaultRowCrossAlignment;

  const AclRow({
    required this.components,
    this.alignment = RowAlignment.left,
    this.gapBefore = 0,
    this.isGapRow = false,
    this.gapRowWeight = 1.0,
    this.separator,
    this.gapRowMinSize = 0,
    this.id,
    this.group,
    this.idScope = false,
    this.breakpoints = const [],
    this.height,
    this.heightBpOverrides = const [],
    this.defaultAppendGap = 8.0,
    this.defaultAppendGapBpOverrides = const [],
    this.defaultRowCrossAlignment = AclRowCrossAlignment.top,
  });

  /// Returns a copy with the named fields replaced and every other field
  /// carried over.
  ///
  /// **The only way the layout passes may rebuild a row.** Three of them do —
  /// hide-unauthorized, the breakpoint split and the inline-variant filter —
  /// and each needs to change two or three fields out of sixteen. Writing that
  /// as a fresh `AclRow(...)` means restating the other thirteen, and a field
  /// added to this class later is then silently absent from every pass that
  /// forgot it: the row keeps all its properties at the width the developer
  /// tested and loses some at the width their user has.
  ///
  /// `test/advanced_container_layout/acl_row_rebuild_test.dart` holds both
  /// halves of that — this method names every field, and no pass constructs an
  /// `AclRow` directly.
  ///
  /// A null argument means *keep what is there*, so this cannot clear a
  /// nullable field ([separator], [id], [group], [height]). No pass needs to:
  /// they narrow, split and filter rows, none of which drops an identity.
  AclRow copyWith({
    List<AclComponent>? components,
    RowAlignment? alignment,
    double? gapBefore,
    bool? isGapRow,
    double? gapRowWeight,
    AclSeparator? separator,
    double? gapRowMinSize,
    String? id,
    String? group,
    bool? idScope,
    List<AclRowBreakpoint>? breakpoints,
    double? height,
    List<(double, double?)>? heightBpOverrides,
    double? defaultAppendGap,
    List<(double, double)>? defaultAppendGapBpOverrides,
    AclRowCrossAlignment? defaultRowCrossAlignment,
  }) {
    return AclRow(
      components: components ?? this.components,
      alignment: alignment ?? this.alignment,
      gapBefore: gapBefore ?? this.gapBefore,
      isGapRow: isGapRow ?? this.isGapRow,
      gapRowWeight: gapRowWeight ?? this.gapRowWeight,
      separator: separator ?? this.separator,
      gapRowMinSize: gapRowMinSize ?? this.gapRowMinSize,
      id: id ?? this.id,
      group: group ?? this.group,
      idScope: idScope ?? this.idScope,
      breakpoints: breakpoints ?? this.breakpoints,
      height: height ?? this.height,
      heightBpOverrides: heightBpOverrides ?? this.heightBpOverrides,
      defaultAppendGap: defaultAppendGap ?? this.defaultAppendGap,
      defaultAppendGapBpOverrides:
          defaultAppendGapBpOverrides ?? this.defaultAppendGapBpOverrides,
      defaultRowCrossAlignment:
          defaultRowCrossAlignment ?? this.defaultRowCrossAlignment,
    );
  }
}

/// Resolves a value carrying `(minWidth, value)` breakpoint overrides.
///
/// The override with the **largest** `minWidth` that is still `<=`
/// [availableWidth] wins; [base] applies when no override qualifies, when
/// there are none, or when the width is not yet known.
///
/// Shared by the row gap, row height and grid column resolvers so the
/// "widest matching breakpoint wins" rule is stated once.
T aclResolveBreakpointed<T>(
  T base,
  List<(double, T)> overrides,
  double? availableWidth,
) {
  if (overrides.isEmpty || availableWidth == null) return base;
  var current = base;
  var best = double.negativeInfinity;
  for (final (minWidth, value) in overrides) {
    if (minWidth <= availableWidth && minWidth >= best) {
      best = minWidth;
      current = value;
    }
  }
  return current;
}

/// Returns the effective gapBefore for [comp] inside [row] at the given
/// [availableWidth], honouring the row's breakpointed default when the
/// component did not carry an explicit distance.
double aclEffectiveGapBefore(
  AclComponent comp,
  AclRow row,
  double? availableWidth,
) {
  if (!comp.gapBeforeIsDefault) return comp.gapBefore;
  return aclResolveBreakpointed(
    row.defaultAppendGap,
    row.defaultAppendGapBpOverrides,
    availableWidth,
  );
}

/// Resolves a breakpointed row height. Returns null if no height is set.
double? aclResolveRowHeight(AclRow row, double? availableWidth) =>
    aclResolveBreakpointed(row.height, row.heightBpOverrides, availableWidth);

// ── Pre-calculation data structures ──────────────────────────────────────────
