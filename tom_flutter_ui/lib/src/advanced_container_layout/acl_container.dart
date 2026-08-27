import 'dart:math' as math;

import 'package:flutter/material.dart';
// `_AclFloorWidthBox` drops to the render layer: measuring a child's minimum
// intrinsic width and clipping instead of overflowing are both below what the
// widget layer exposes.
import 'package:flutter/rendering.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../theme/tom_theme.dart';
import 'acl_flags.dart';
import 'acl_device_context.dart';
import 'acl_group_visibility.dart';
import 'acl_responsive.dart';
import 'acl_scope.dart';
import 'row_alignment.dart';

// ── Border enums / types ─────────────────────────────────────────────────────

/// Defines the visual shape of a container border.
enum AclBorderKind {
  none,
  solid,
  solidDouble,
  top,
  bottom,
  left,
  right,
  horizontal,
  vertical,
}

/// Axis point on the X axis.
enum AclAxisPointX { left, center, right }

/// Axis point on the Y axis.
enum AclAxisPointY { top, center, bottom }

/// Per-component vertical placement within its row when [AclComponent.alignYToKey] is null.
enum AclRowCrossAlignment { top, center, bottom }

/// Layout direction for ACL containers: the order in which a row places its
/// components along the horizontal axis.
///
/// See "Layout Direction (RTL/LTR)" (§30) in
/// `doc/acl_design_specification.md`.
enum AclDirection { ltr, rtl }

/// Provides an [AclDirection] to descendant [AclContainer] widgets.
///
/// Containers that have no explicit [AclContainer.direction] will
/// use the direction from the nearest [AclDirectionScope] ancestor,
/// falling back to [AclDirection.ltr] when no scope is present.
class AclDirectionScope extends InheritedWidget {
  final AclDirection direction;

  const AclDirectionScope({
    super.key,
    required this.direction,
    required super.child,
  });

  static AclDirection? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AclDirectionScope>()
        ?.direction;
  }

  @override
  bool updateShouldNotify(AclDirectionScope oldWidget) =>
      direction != oldWidget.direction;
}

// ── Separator types ──────────────────────────────────────────────────────────

enum AclSeparatorStyle { single, doubleLine }

enum AclSeparatorAlignment { top, middle, bottom }

/// Horizontal divider drawn inside a gap row.
class AclSeparator {
  final AclSeparatorStyle style;
  final Color? color;
  final double lineWidth;
  final AclSeparatorAlignment alignment;

  const AclSeparator({
    this.style = AclSeparatorStyle.single,
    this.color,
    this.lineWidth = 1.0,
    this.alignment = AclSeparatorAlignment.middle,
  });
}

// ── AclBorderStyle ───────────────────────────────────────────────────────────

class AclBorderStyle {
  final AclBorderKind kind;
  final Color color;
  final double lineWidth;
  final bool rounded;
  final double borderRadius;
  final EdgeInsetsGeometry borderInsets;

  const AclBorderStyle({
    this.kind = AclBorderKind.none,
    this.color = const Color(0xFF9E9E9E),
    this.lineWidth = 1.0,
    this.rounded = false,
    this.borderRadius = 8.0,
    this.borderInsets = EdgeInsets.zero,
  });

  const AclBorderStyle.none()
    : kind = AclBorderKind.none,
      color = Colors.transparent,
      lineWidth = 0,
      rounded = false,
      borderRadius = 0,
      borderInsets = EdgeInsets.zero;

  const AclBorderStyle.solid({
    this.color = const Color(0xFF9E9E9E),
    this.lineWidth = 1.0,
    this.rounded = false,
    this.borderRadius = 8.0,
    this.borderInsets = EdgeInsets.zero,
  }) : kind = AclBorderKind.solid;

  bool get enabled => kind != AclBorderKind.none;

  AclBorderStyle copyWith({
    AclBorderKind? kind,
    Color? color,
    double? lineWidth,
    bool? rounded,
    double? borderRadius,
    EdgeInsetsGeometry? borderInsets,
  }) {
    return AclBorderStyle(
      kind: kind ?? this.kind,
      color: color ?? this.color,
      lineWidth: lineWidth ?? this.lineWidth,
      rounded: rounded ?? this.rounded,
      borderRadius: borderRadius ?? this.borderRadius,
      borderInsets: borderInsets ?? this.borderInsets,
    );
  }
}

// ── AclComponent ─────────────────────────────────────────────────────────────

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
    return copyWith(
      gapBefore: newGap,
      gapBeforeIsDefault: gapBeforeIsDefault,
    );
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

  /// Returns a copy with [components] and [gapBefore] replaced. Used by the
  /// hide-unauthorized pass when it rewrites a row that has had some of
  /// its components dropped or when the row itself inherits a reduced
  /// gap because the previous row was elided.
  AclRow copyWith({
    List<AclComponent>? components,
    double? gapBefore,
  }) {
    return AclRow(
      components: components ?? this.components,
      alignment: alignment,
      gapBefore: gapBefore ?? this.gapBefore,
      isGapRow: isGapRow,
      gapRowWeight: gapRowWeight,
      separator: separator,
      gapRowMinSize: gapRowMinSize,
      id: id,
      group: group,
      idScope: idScope,
      breakpoints: breakpoints,
      height: height,
      heightBpOverrides: heightBpOverrides,
      defaultAppendGap: defaultAppendGap,
      defaultAppendGapBpOverrides: defaultAppendGapBpOverrides,
      defaultRowCrossAlignment: defaultRowCrossAlignment,
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
    aclResolveBreakpointed(
      row.height,
      row.heightBpOverrides,
      availableWidth,
    );

// ── Pre-calculation data structures ──────────────────────────────────────────

/// Pre-computed layout values for a single content row, produced by the
/// pre-calculation loop. These values are handed directly to [_buildRow] so
/// that Flutter layout is performed in a single pass with all sizes fixed.
class _AclRowLayout {
  /// Fitted (phase 1/2/3) widths by component index. null → natural size.
  final Map<int, double> fittedWidths;

  /// Computed horizontal translation delta for each component index.
  /// 0.0 for components that have no alignXToKey.
  final Map<int, double> horizontalDeltas;

  /// Computed vertical translation delta for each component index.
  /// 0.0 for components that have no alignYToKey.
  final Map<int, double> verticalDeltas;

  /// Resolved linked widths (from sameWidthAs / sameSize) by component index.
  final Map<int, double> linkedWidths;

  /// Resolved linked heights (from sameHeightAs / sameSize) by component index.
  final Map<int, double> linkedHeights;

  /// Width assigned to each gap slot by component index (0 when scrollableX).
  final Map<int, double> gapSlotWidths;

  /// Virtual rect for every component (by componentKey). Published for
  /// cross-row constraint resolution in subsequent rows.
  final Map<Key, Rect> virtualRects;

  /// Estimated row height from the pre-calc pass.
  final double estimatedHeight;

  /// Minimum horizontal X position (may be negative for shifted components).
  final double minHorizontalX;

  _AclRowLayout({
    required this.fittedWidths,
    required this.horizontalDeltas,
    required this.verticalDeltas,
    required this.linkedWidths,
    required this.linkedHeights,
    required this.gapSlotWidths,
    required this.virtualRects,
    required this.estimatedHeight,
    this.minHorizontalX = 0.0,
  });
}

// ── AclContainer ─────────────────────────────────────────────────────────────

class AclContainer extends StatefulWidget {
  final List<AclRow> rows;
  final AclBorderStyle borderStyle;
  final AclBorderStyle? focusedBorderStyle;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;

  /// Enables horizontal scrolling; gap slots collapse to 0 on the X axis.
  final bool scrollableX;

  /// Enables vertical scrolling; gap rows collapse to 0 on the Y axis.
  final bool scrollableY;

  /// Optional preferred container size. Acts as the minimum when no explicit
  /// minimum is set. Maximum is unlimited unless [maximumContainerSize] is set.
  final Size? preferredContainerSize;

  /// Optional minimum container size.
  final Size? minimumContainerSize;

  /// Optional maximum container size.
  final Size? maximumContainerSize;

  /// Optional identifier for this container. Whether it reaches descendant
  /// paths depends on [idScope].
  ///
  /// See "Container IDs" (§24) in `doc/acl_design_specification.md`.
  final String? aclId;

  /// Whether this container contributes its ID to descendant paths.
  ///
  /// - `true` — identity container: ID appears in descendant paths.
  /// - `false` — layout container (default): ID is for own resources only.
  final bool idScope;

  /// Optional group name for the entire container, letting a
  /// [AclGroupVisibilityController] act on everything it holds at once.
  ///
  /// See "Groups" (§25) in `doc/acl_design_specification.md`.
  final String? aclGroup;

  /// Parent container ID for building the full ID path — the prefix this
  /// container's own [aclId] is appended to when it is nested.
  ///
  /// See "Container IDs" (§24) in `doc/acl_design_specification.md`.
  final String? parentIdPath;

  /// Group visibility controllers keyed by group name. Only groups with an
  /// entry here can be shown, hidden or disabled; membership alone does
  /// nothing.
  ///
  /// See "Group Visibility Control" (§26) in
  /// `doc/acl_design_specification.md`.
  final Map<String, AclGroupVisibilityController> groupVisibilityControllers;

  /// Responsive variants sorted by atWidth descending. A variant supplies
  /// replacement [rows] and nothing else — the container's chrome does not
  /// change with the active variant.
  ///
  /// See "Responsive Variants" (§27) in `doc/acl_design_specification.md`.
  final List<AclVariant> variants;

  /// Layout direction: LTR (default) or RTL.
  /// If null, falls back to the nearest [AclDirectionScope], then [AclDirection.ltr].
  ///
  /// See "Layout Direction (RTL/LTR)" (§30) in
  /// `doc/acl_design_specification.md`.
  final AclDirection? direction;

  /// Default for per-component `hideUnauthorized`. When `true`, any
  /// component whose child implements [TomAuthorizable] and currently
  /// resolves to [TomAuthState.none] is **removed from its row before
  /// layout**, together with the `gapBefore` of the component that
  /// follows it in the same row. If a row ends up with no components it
  /// is dropped in turn, along with the `gapBefore` of the next row.
  ///
  /// Components can opt in or out individually via
  /// [AclComponent.hideUnauthorized] (typically set through the builder's
  /// `setHideUnauthorized(bool)` fluent call).
  final bool defaultHideUnauthorized;

  const AclContainer({
    super.key,
    required this.rows,
    this.borderStyle = const AclBorderStyle.none(),
    this.focusedBorderStyle,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.scrollableX = false,
    this.scrollableY = false,
    this.preferredContainerSize,
    this.minimumContainerSize,
    this.maximumContainerSize,
    this.aclId,
    this.idScope = false,
    this.aclGroup,
    this.parentIdPath,
    this.groupVisibilityControllers = const {},
    this.variants = const [],
    this.direction,
    this.defaultHideUnauthorized = false,
  });

  @override
  State<AclContainer> createState() => _AclContainerState();
}

class _AclContainerState extends State<AclContainer> {
  static const double _geometryEpsilon = 0.5;
  static const int _maxPreCalcIterations = 20;

  final FocusNode _focusNode = FocusNode();
  bool _hasFocusWithin = false;
  bool _naturalSizeCacheRefreshScheduled = false;

  /// Cache of measured natural sizes for components with no explicit ACL size
  /// hints. Populated by the post-frame callback; used as the seed for the
  /// pre-calculation loop. Keys are the component's [AclComponent.componentKey].
  final Map<Key, Size> _naturalSizeCache = {};

  /// Measured minimum widths of components whose preferred width was *not*
  /// declared by the author but auto-applied by `AclBuilder`
  /// ([AclComponent.preferredWidthIsDefault]).
  ///
  /// The value is the narrowest width at which the child can be painted without
  /// overflowing — its minimum intrinsic width — reported from layout by
  /// [_AclFloorWidthBox]. Kept apart from [_naturalSizeCache] on purpose: that
  /// cache holds *rendered* sizes of components carrying no ACL hints at all,
  /// and mixing a lower bound into it would change how those are estimated.
  /// Keys are the component's [AclComponent.componentKey].
  final Map<Key, double> _measuredDefaultWidths = {};
  bool _measuredDefaultWidthRebuildScheduled = false;

  @override
  void initState() {
    super.initState();
    _subscribeVisibilityControllers();
  }

  @override
  void dispose() {
    _unsubscribeVisibilityControllers();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AclContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-subscribe if controllers changed.
    if (!identical(
      oldWidget.groupVisibilityControllers,
      widget.groupVisibilityControllers,
    )) {
      _unsubscribeVisibilityControllers(oldWidget.groupVisibilityControllers);
      _subscribeVisibilityControllers();
    }
    // AclBuilder generates new GlobalKeys on every build() call. Transfer
    // cached natural sizes from old keys to new keys by structural position
    // (row index × component index) so there is no one-frame cache-miss lag
    // after a parent rebuild.
    _remapNaturalSizeCacheByPosition(oldWidget.rows, widget.rows);
  }

  void _subscribeVisibilityControllers([
    Map<String, AclGroupVisibilityController>? controllers,
  ]) {
    for (final ctrl
        in (controllers ?? widget.groupVisibilityControllers).values) {
      ctrl.modeNotifier.addListener(_onVisibilityChanged);
    }
  }

  void _unsubscribeVisibilityControllers([
    Map<String, AclGroupVisibilityController>? controllers,
  ]) {
    for (final ctrl
        in (controllers ?? widget.groupVisibilityControllers).values) {
      ctrl.modeNotifier.removeListener(_onVisibilityChanged);
    }
  }

  void _onVisibilityChanged() {
    if (mounted) setState(() {});
  }

  void _remapNaturalSizeCacheByPosition(
    List<AclRow> oldRows,
    List<AclRow> newRows,
  ) {
    final newCache = <Key, Size>{};
    final newMeasured = <Key, double>{};
    final minRows = math.min(oldRows.length, newRows.length);
    for (int ri = 0; ri < minRows; ri++) {
      final oldComps = oldRows[ri].components;
      final newComps = newRows[ri].components;
      final len = math.min(oldComps.length, newComps.length);
      for (int ci = 0; ci < len; ci++) {
        final oldKey = oldComps[ci].componentKey;
        final newKey = newComps[ci].componentKey;
        if (newKey == null) continue;
        final sz = oldKey != null ? _naturalSizeCache[oldKey] : null;
        if (sz != null) newCache[newKey] = sz;
        final measured =
            oldKey != null ? _measuredDefaultWidths[oldKey] : null;
        if (measured != null) newMeasured[newKey] = measured;
      }
    }
    _naturalSizeCache
      ..clear()
      ..addAll(newCache);
    _measuredDefaultWidths
      ..clear()
      ..addAll(newMeasured);
  }

  // ── Auto-defaulted preferred widths ───────────────────────────────────────

  /// Records the minimum width [key]'s child needs, reported from layout by
  /// [_AclFloorWidthBox].
  ///
  /// Called during layout, so the rebuild it may need is deferred to the next
  /// frame — the same post-frame discipline the natural-size cache uses.
  void _reportMeasuredDefaultWidth(Key key, double minWidth) {
    if (!minWidth.isFinite || minWidth < 0) return;
    final previous = _measuredDefaultWidths[key];
    if (previous != null && (previous - minWidth).abs() < _geometryEpsilon) {
      return;
    }
    _measuredDefaultWidths[key] = minWidth;
    if (_measuredDefaultWidthRebuildScheduled) return;
    _measuredDefaultWidthRebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measuredDefaultWidthRebuildScheduled = false;
      if (mounted) setState(() {});
    });
  }

  /// Widens components whose preferred width was auto-defaulted and whose
  /// content has been measured as needing more than the default.
  ///
  /// This is the point at which the default stops being a cap: the widened
  /// value flows into the *whole* pre-calculation — planned X positions, row
  /// estimates, the fit/shrink distribution and `getRect()` — so the geometry
  /// the engine computes in pure Dart stays the geometry that is rendered.
  /// Widening here rather than at the individual read sites is what keeps that
  /// true: a component is one declared width to everything downstream.
  ///
  /// The first frame has no measurement and uses the plain default; the
  /// measurement arrives from that frame's layout and the container rebuilds
  /// once. Until it does — and whenever the row is too tight for the widened
  /// width — [_AclFloorWidthBox] clips rather than overflows.
  List<AclRow> _applyMeasuredDefaultWidths(List<AclRow> rows) {
    if (_measuredDefaultWidths.isEmpty) return rows;
    List<AclRow>? rewritten;
    for (int ri = 0; ri < rows.length; ri++) {
      final row = rows[ri];
      List<AclComponent>? components;
      for (int ci = 0; ci < row.components.length; ci++) {
        final widened = _widenedByMeasurement(row.components[ci]);
        if (widened == null) continue;
        components ??= List<AclComponent>.of(row.components);
        components[ci] = widened;
      }
      if (components == null) continue;
      rewritten ??= List<AclRow>.of(rows);
      rewritten[ri] = row.copyWith(components: components);
    }
    return rewritten ?? rows;
  }

  /// The component with its auto-defaulted preferred width raised to the
  /// measured minimum, or `null` when nothing needs to change.
  AclComponent? _widenedByMeasurement(AclComponent component) {
    if (!component.preferredWidthIsDefault) return null;
    final key = component.componentKey;
    final declared = component.preferredSize?.width;
    if (key == null || declared == null) return null;
    final measured = _measuredDefaultWidths[key];
    if (measured == null) return null;
    // An author-declared maximum still caps the widening — the auto-applied
    // default is the only thing this pass is allowed to overrule.
    final cap = component.maximumSize?.width;
    final width =
        (cap != null && cap.isFinite) ? math.min(measured, cap) : measured;
    if (width <= declared + _geometryEpsilon) return null;
    return component.copyWith(
      preferredSize: Size(width, component.preferredSize!.height),
    );
  }

  /// Selects the appropriate variant rows based on [availableWidth], or
  /// returns the default [widget.rows] if no variant matches.
  List<AclRow> _selectVariantRows(double? availableWidth) {
    if (widget.variants.isEmpty || availableWidth == null) return widget.rows;
    // Variants are sorted by atWidth ascending. Pick the first (narrowest)
    // whose threshold exceeds availableWidth — this is the most specific match.
    for (final variant in widget.variants) {
      if (availableWidth < variant.atWidth) {
        return variant.rows;
      }
    }
    return widget.rows;
  }

  /// Applies row breakpoints: splits a row into multiple rows when
  /// [availableWidth] drops below the breakpoint threshold.
  List<AclRow> _applyRowBreakpoints(List<AclRow> rows, double? availableWidth) {
    if (availableWidth == null) return rows;
    final result = <AclRow>[];
    for (final row in rows) {
      if (row.isGapRow || row.breakpoints.isEmpty) {
        result.add(row);
        continue;
      }
      // Collect active breakpoints (sorted smallest atWidth first).
      final active =
          row.breakpoints.where((bp) => availableWidth < bp.atWidth).toList()
            ..sort((a, b) => a.splitAfter.compareTo(b.splitAfter));
      if (active.isEmpty) {
        result.add(row);
        continue;
      }
      // Build split indices (1-based → 0-based boundary).
      final splitIndices = <int>{};
      for (final bp in active) {
        splitIndices.add(bp.splitAfter.clamp(1, row.components.length));
      }
      final sorted = splitIndices.toList()..sort();
      int start = 0;
      for (int i = 0; i < sorted.length; i++) {
        final end = sorted[i];
        if (end <= start || end > row.components.length) continue;
        final dist = i == 0
            ? row.gapBefore
            : active
                  .firstWhere(
                    (b) => b.splitAfter == end,
                    orElse: () => active.first,
                  )
                  .splitRowDist;
        result.add(
          AclRow(
            components: row.components.sublist(start, end),
            alignment: row.alignment,
            gapBefore: i == 0 ? row.gapBefore : dist,
            // Every fragment keeps the id: a split is a visual wrap of one
            // logical row, so all fragments must resolve the same row policy
            // and contribute the same path segment. Dropping it on the
            // continuation fragments would make a hidden row leak its
            // overflow components, and would move descendant policy paths
            // as the window narrows.
            id: row.id,
            idScope: row.idScope,
            group: row.group,
            breakpoints: const [],
            height: row.height,
            heightBpOverrides: row.heightBpOverrides,
            defaultAppendGap: row.defaultAppendGap,
            defaultAppendGapBpOverrides: row.defaultAppendGapBpOverrides,
          ),
        );
        start = end;
      }
      if (start < row.components.length) {
        result.add(
          AclRow(
            components: row.components.sublist(start),
            alignment: row.alignment,
            gapBefore: active.last.splitRowDist,
            id: row.id,
            idScope: row.idScope,
            group: row.group,
            breakpoints: const [],
            height: row.height,
            heightBpOverrides: row.heightBpOverrides,
            defaultAppendGap: row.defaultAppendGap,
            defaultAppendGapBpOverrides: row.defaultAppendGapBpOverrides,
          ),
        );
      }
    }
    return result;
  }

  /// Filters components within each row based on inline variant detectors.
  /// Components not in any variant block are always kept. Components in a
  /// variant block are kept only when their detector is the active one.
  ///
  /// See "Inline Component Variants" (§29) in
  /// `doc/acl_design_specification.md`.
  List<AclRow> _applyInlineVariants(
    List<AclRow> rows,
    AclDeviceContext? deviceContext,
    Acl? acl,
    BuildContext buildContext,
  ) {
    final result = <AclRow>[];
    for (final row in rows) {
      if (row.isGapRow) {
        result.add(row);
        continue;
      }
      final hasInline = row.components.any((c) => c.inlineVariant);
      if (!hasInline) {
        result.add(row);
        continue;
      }

      // Collect unique detectors in declaration order (by identity).
      final detectorOrder = <AclVariantDetector?>[];
      final seen = <AclVariantDetector?>{};
      for (final c in row.components) {
        if (!c.inlineVariant) continue;
        if (seen.add(c.variantDetector)) {
          detectorOrder.add(c.variantDetector);
        }
      }

      // Evaluate non-default detectors in declaration order.
      // First detector returning true wins.
      AclVariantDetector? activeDetector;
      bool matched = false;
      if (deviceContext != null) {
        for (final detector in detectorOrder) {
          if (detector == null) continue; // skip default for now
          if (detector(deviceContext, acl, buildContext)) {
            activeDetector = detector;
            matched = true;
            break;
          }
        }
      }

      // Filter: non-variant components always kept.
      // If a detector matched: keep variant components with that detector.
      // If no detector matched: keep default variant components (null).
      final filtered = row.components.where((c) {
        if (!c.inlineVariant) return true;
        if (matched) return identical(c.variantDetector, activeDetector);
        return c.variantDetector == null;
      }).toList();

      if (filtered.isEmpty) continue;
      result.add(
        AclRow(
          components: filtered,
          alignment: row.alignment,
          gapBefore: row.gapBefore,
          isGapRow: row.isGapRow,
          gapRowWeight: row.gapRowWeight,
          separator: row.separator,
          gapRowMinSize: row.gapRowMinSize,
          id: row.id,
          idScope: row.idScope,
          group: row.group,
          breakpoints: row.breakpoints,
          height: row.height,
          heightBpOverrides: row.heightBpOverrides,
          defaultAppendGap: row.defaultAppendGap,
          defaultAppendGapBpOverrides: row.defaultAppendGapBpOverrides,
        ),
      );
    }
    return result;
  }

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
    if (widget.idScope &&
        widget.aclId != null &&
        widget.aclId!.isNotEmpty) {
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

    if (widget.idScope &&
        widget.aclId != null &&
        widget.aclId!.isNotEmpty) {
      segments.add(widget.aclId!);
    }

    if (groupName != null && groupName.isNotEmpty) {
      segments.add(groupName);
    }

    segments.add(rowId);
    return segments.join('.');
  }

  /// Wraps a component with [AclScope] to provide ID/group metadata.
  Widget _wrapWithScope(
    Widget child,
    AclComponent comp,
    AclRow row, {
    String? groupName,
    String? fullPath,
  }) {
    final containerId = widget.aclId;
    final resolvedGroup = groupName ?? comp.group ?? row.group;
    final resolvedPath =
        fullPath ??
        (comp.id != null
            ? _buildComponentPolicyPath(
                componentId: comp.id!,
                groupName: resolvedGroup,
                row: row,
              )
            : null);

    // AclScope provides ACL-specific metadata for descendant lookups.
    // TomNodeScope propagation is handled at the container level
    // (by TomAclBuilder / TomContainerBase) — no need to duplicate here.
    return AclScope(
      containerId: containerId,
      componentId: comp.id,
      rowId: row.id,
      groupName: resolvedGroup,
      fullIdPath: resolvedPath,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content = _buildContent(context);

    // Clip overflow when the available space is smaller than content needs.
    // This prevents visual overflow (paint outside bounds) and replaces the
    // yellow/black striped overflow indicator with a clean clip.
    content = ClipRect(child: content);

    // Container-level height/width constraints. minContW is handled inside
    // _buildContent (inside LayoutBuilder) so expandX/gap use the correct width.
    final minContH =
        widget.minimumContainerSize?.height ??
        widget.preferredContainerSize?.height;
    final maxContW = widget.maximumContainerSize?.width;
    final maxContH = widget.maximumContainerSize?.height;
    if (minContH != null || maxContW != null || maxContH != null) {
      content = ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: minContH ?? 0,
          maxWidth: maxContW ?? double.infinity,
          maxHeight: maxContH ?? double.infinity,
        ),
        child: content,
      );
    }

    // Post-frame: re-measure natural-sized components. If any size changed,
    // trigger one rebuild. This is the ONLY path that reads the render tree.
    _scheduleNaturalSizeCacheRefresh();

    final activeBorderStyle =
        _hasFocusWithin && widget.focusedBorderStyle != null
        ? widget.focusedBorderStyle!
        : widget.borderStyle;

    final hasExplicitPadding = widget.padding != EdgeInsets.zero;
    if (hasExplicitPadding) {
      content = Padding(padding: widget.padding, child: content);
    }

    content = _wrapWithBorder(
      content,
      activeBorderStyle,
      suppressDefaultInsets: hasExplicitPadding,
    );

    return Focus(
      focusNode: _focusNode,
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (hasFocus) {
        if (_hasFocusWithin == hasFocus || !mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _hasFocusWithin == hasFocus) return;
          setState(() {
            _hasFocusWithin = hasFocus;
          });
        });
      },
      child: content,
    );
  }

  void _scheduleNaturalSizeCacheRefresh() {
    if (_naturalSizeCacheRefreshScheduled) return;
    _naturalSizeCacheRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _naturalSizeCacheRefreshScheduled = false;
      if (!mounted) return;

      bool changed = false;
      for (final row in widget.rows) {
        for (final comp in row.components) {
          final key = comp.componentKey;
          if (key is! GlobalKey) continue;
          // Only refresh entries for natural-sized components (no ACL hints).
          // Explicitly-sized components never enter the cache.
          if (comp.preferredSize != null ||
              comp.minimumSize != null ||
              comp.maximumSize != null ||
              comp.useOtherDimX ||
              comp.useOtherDimY) {
            continue;
          }

          final ctx = key.currentContext;
          final ro = ctx?.findRenderObject();
          if (ro is! RenderBox || !ro.hasSize) continue;
          final size = ro.size;
          final cached = _naturalSizeCache[key];
          if (cached == null ||
              (cached.width - size.width).abs() >= _geometryEpsilon ||
              (cached.height - size.height).abs() >= _geometryEpsilon) {
            _naturalSizeCache[key] = size;
            changed = true;
          }
        }
      }

      if (changed && mounted) setState(() {});
    });
  }

  // ── Fitted width calculation (pure Dart — no render tree reads) ─────────────

  /// Returns fitted widths for components that need shrinking or growing to fit
  /// [availableWidth]. Returns `null` if no adjustment is needed.
  ///
  /// [linkedWidths] — pre-resolved sameWidthAs / sameSize widths (index → width).
  Map<int, double>? _computeFittedWidths({
    required AclRow row,
    required double availableWidth,
    required Map<Key, Rect> crossRowVirtualRects,
    Map<int, double> linkedWidths = const {},
  }) {
    double plannedX = 0;
    double minHX = 0;
    double maxHX = 0;
    final vRects = <Key, Rect>{};
    final prefWidths = <int, double>{};

    bool skip(AclComponent c) =>
        c.isGap ||
        c.child is Flexible ||
        c.child is Expanded ||
        c.child is Spacer ||
        c.expandX ||
        c.alignXToKey != null;

    // For the SHRINK phase we include expandX components so they shrink
    // alongside everyone else toward their minimum. In the grow phase
    // they stay out (expandXWidths handles surplus) but once the row is
    // tighter than natural width, treating expandX the same as any other
    // component avoids it collapsing to 0 before the non-expandX
    // neighbours start shrinking.
    bool skipForShrink(AclComponent c) =>
        c.isGap ||
        c.child is Flexible ||
        c.child is Expanded ||
        c.child is Spacer ||
        c.alignXToKey != null;

    for (int i = 0; i < row.components.length; i++) {
      final comp = row.components[i];
      if (skip(comp)) continue;

      final linkedW =
          linkedWidths[i] ??
          (comp.useOtherDimX
              ? crossRowVirtualRects[comp.referenceKey]?.width
              : null);

      final bool collapseToVisual =
          comp.alignXToKey == null && maxHX < plannedX;
      final effectiveGap = aclEffectiveGapBefore(comp, row, availableWidth);
      if (effectiveGap > 0 && !collapseToVisual) plannedX += effectiveGap;

      final delta = collapseToVisual
          ? (maxHX + effectiveGap - plannedX)
          : _calcHorizontalDelta(
              comp: comp,
              plannedX: plannedX,
              linkedWidth: linkedW,
              virtualRects: vRects,
              crossRowVirtualRects: crossRowVirtualRects,
              fittedWidths: const {},
            );

      if (delta > 0) plannedX += delta;

      final pref =
          (linkedW ?? comp.preferredSize?.width ?? comp.minimumSize?.width ?? 0)
              .clamp(0.0, double.infinity);
      prefWidths[i] = pref;

      // Use non-zero preferredSize.height when set explicitly; otherwise
      // fall through to minimumSize or natural height.  The auto-default
      // Size(150, 0) sets height to 0 which must NOT suppress intrinsic height.
      final prefH = comp.preferredSize?.height;
      final h = (prefH != null && prefH > 0
              ? prefH
              : (comp.minimumSize?.height ?? _naturalHeight(comp) ?? 0))
          .clamp(0.0, double.infinity);
      final shiftedLeft = plannedX + (delta < 0 ? delta : 0);
      minHX = math.min(minHX, shiftedLeft);
      maxHX = math.max(maxHX, shiftedLeft + pref);

      final key = comp.componentKey;
      if (key != null) vRects[key] = Rect.fromLTWH(shiftedLeft, 0, pref, h);
      plannedX += pref;
    }

    final extraLeft = minHX < 0 ? -minHX : 0.0;
    final naturalWidth = maxHX + extraLeft;

    // Extend natural width to include expandX components' preferred widths
    // (+ the gap before each). The top loop skips expandX so the row is
    // considered to "fit" even when the expandX preferred widths wouldn't.
    // Including them here makes the grow/shrink split respect the
    // caller's preferred widths for every component, not just the
    // non-expandX subset — so shrinking kicks in at the right threshold
    // and expandX joins the shrink distribution from the first pixel of
    // deficit.
    double naturalWithExpandX = naturalWidth;
    final expandXPrefs = <int, double>{};
    for (int i = 0; i < row.components.length; i++) {
      final comp = row.components[i];
      if (!comp.expandX || comp.isGap) continue;
      if (comp.child is Flexible ||
          comp.child is Expanded ||
          comp.child is Spacer) {
        continue;
      }
      final pref = comp.preferredSize?.width ??
          comp.minimumSize?.width ??
          _naturalWidth(comp) ??
          0.0;
      expandXPrefs[i] = pref;
      naturalWithExpandX +=
          pref + aclEffectiveGapBefore(comp, row, availableWidth);
    }

    if (naturalWithExpandX <= availableWidth) {
      // ── Grow phase ─────────────────────────────────────────────────────
      // When there is an expandX (or gap) in the row, non-expandX components
      // stay pinned at their preferred size — surplus flows to the expandX
      // components via `expandXWidths` in _computeRowLayout. When there is
      // no expandX/gap, non-expandX components themselves absorb the surplus
      // so the row always fills the available width.
      //
      // Surplus distribution weight per component is (P/M − 1): components
      // with a larger ratio between preferred and minimum size take a larger
      // share. A component with M=0 (no explicit minimum) falls back to
      // weight 1 so it still participates. Each component is clamped at its
      // maximumSize (if set); any unused growth from clamped components is
      // redistributed by the same rule until no component can absorb more.
      final hasRowFiller = row.components.any(
        (c) => (c.expandX && !c.isGap) || c.isGap,
      );
      if (!hasRowFiller) {
        double naturalExcludedWidth = 0;
        for (int i = 0; i < row.components.length; i++) {
          final comp = row.components[i];
          if (skip(comp)) continue;
          if (comp.preferredSize != null ||
              comp.minimumSize != null ||
              comp.maximumSize != null ||
              comp.useOtherDimX) {
            continue;
          }
          // Use cached natural width as seed; falls back to 0 on first frame.
          naturalExcludedWidth +=
              _naturalWidth(comp) ??
              (comp.child is SizedBox
                  ? ((comp.child as SizedBox).width ?? 0.0)
                  : 0.0);
        }

        // alignX*-positioned components were excluded from `naturalWidth`
        // (they're placed by cross-row alignment, not sequentially) but
        // they still occupy horizontal space in the row. Count their
        // preferred widths + the gap that precedes them, otherwise the
        // non-aligned growable components would over-grow and push the
        // row past `availableWidth`, producing a visible RenderFlex
        // overflow on layouts like reference_constraints /
        // comprehensive_form.
        double alignedOccupiedWidth = 0;
        for (int i = 0; i < row.components.length; i++) {
          final comp = row.components[i];
          if (comp.alignXToKey == null) continue;
          if (comp.isGap) continue;
          if (comp.child is Flexible ||
              comp.child is Expanded ||
              comp.child is Spacer) {
            continue;
          }
          final pref = comp.preferredSize?.width ??
              comp.minimumSize?.width ??
              _naturalWidth(comp) ??
              0.0;
          alignedOccupiedWidth +=
              pref + aclEffectiveGapBefore(comp, row, availableWidth);
        }

        double surplus = math.max(
          0.0,
          availableWidth -
              naturalWidth -
              naturalExcludedWidth -
              alignedOccupiedWidth,
        );
        if (surplus < 1) return null;

        // Collect growable components and their (P/M − 1) weights. A
        // component participates in horizontal growth only when BOTH a
        // minimum and a preferred width are set with min < pref — that
        // is what defines the growth direction and magnitude in the
        // caller's model. Components without an explicit minimum
        // (setMSize not called) stay pinned at their preferred width;
        // components with min == pref (no growth room) also stay put.
        final growable = <int>[];
        final weights = <int, double>{};
        final currentWidths = <int, double>{};
        for (int i = 0; i < row.components.length; i++) {
          final comp = row.components[i];
          if (skip(comp)) continue;
          if (comp.useOtherDimX) continue;
          final minW = comp.minimumSize?.width;
          final prefW = comp.preferredSize?.width;
          if (minW == null || prefW == null) continue;
          if (!minW.isFinite || minW <= 0) continue;
          if (prefW <= minW) continue;
          final weight = prefW / minW - 1.0;
          if (!weight.isFinite || weight <= 0) continue;
          growable.add(i);
          weights[i] = weight;
          currentWidths[i] = prefWidths[i] ?? prefW;
        }
        if (growable.isEmpty) return null;

        // Iteratively grow. A component that hits its maximumSize drops out
        // of the weighted pool; the remainder keeps sharing the leftover.
        final unclamped = {...growable};
        while (surplus >= 1 && unclamped.isNotEmpty) {
          final weightSum = unclamped.fold<double>(0.0,
              (s, i) => s + weights[i]!);
          if (weightSum <= 0) break;
          var distributedThisRound = 0.0;
          // Snapshot to avoid mutating during iteration.
          for (final i in unclamped.toList()) {
            final share = surplus * (weights[i]! / weightSum);
            final max = row.components[i].maximumSize?.width;
            final current = currentWidths[i]!;
            double grown = current + share;
            double actualGrowth = share;
            if (max != null && max.isFinite && grown > max) {
              actualGrowth = math.max(0.0, max - current);
              grown = max;
              unclamped.remove(i);
            }
            currentWidths[i] = grown;
            distributedThisRound += actualGrowth;
          }
          surplus -= distributedThisRound;
          if (distributedThisRound < 0.5) break; // avoid infinite churn
        }
        return currentWidths;
      }
      return null;
    }

    // ── Shrink phase ────────────────────────────────────────────────────────
    // Components shrink from preferred towards minimum. When no explicit
    // minimumSize is set the floor is 0 — NOT preferredSize — so that
    // auto-defaulted components (150×0) can still participate in shrinking.
    //
    // expandX components participate in the shrink phase too: once the
    // row is tighter than natural width they shrink alongside everyone
    // else, proportionally to (pref − min). Otherwise expandX would
    // collapse to 0 (via _computeRowLayout's expandPool clamp) long
    // before the non-expandX neighbours start giving up space.
    final deficit = naturalWithExpandX - availableWidth;
    if (deficit < 1) return null;

    double shrinkCap = 0;
    for (int i = 0; i < row.components.length; i++) {
      final comp = row.components[i];
      if (skipForShrink(comp)) continue;
      if (comp.useOtherDimX) continue;
      final pref = expandXPrefs[i] ?? prefWidths[i] ?? 0.0;
      shrinkCap += math.max(
        0.0,
        pref - (comp.minimumSize?.width ?? 0),
      );
    }
    if (shrinkCap < 1) return null;

    final ratio = (deficit / shrinkCap).clamp(0.0, 1.0);
    final fitted = <int, double>{};
    for (int i = 0; i < row.components.length; i++) {
      final comp = row.components[i];
      if (skipForShrink(comp)) continue;
      if (comp.useOtherDimX) continue;
      if (comp.preferredSize == null && comp.minimumSize == null) continue;
      final pref = expandXPrefs[i] ?? prefWidths[i] ?? 0.0;
      final min = comp.minimumSize?.width ?? 0.0;
      fitted[i] = pref - math.max(0.0, pref - min) * ratio;
    }
    return fitted;
  }

  // ── Border rendering ───────────────────────────────────────────────────────

  Widget _wrapWithBorder(
    Widget content,
    AclBorderStyle style, {
    bool suppressDefaultInsets = false,
  }) {
    final hasBackground = widget.backgroundColor != null;

    if (!style.enabled) {
      if (!hasBackground) return content;
      return Container(color: widget.backgroundColor, child: content);
    }

    final color = style.color;
    final radius = style.rounded ? style.borderRadius : 0.0;

    final contentWithInsets = style.borderInsets != EdgeInsets.zero
        ? Padding(padding: style.borderInsets, child: content)
        // Default inner insets: 4 px on all sides when border is active and
        // no explicit borderInsets were configured. Suppressed when the
        // container has explicit padding (which replaces the default insets).
        : (style.enabled && !suppressDefaultInsets)
        ? Padding(padding: const EdgeInsets.all(4), child: content)
        : content;

    if (style.kind == AclBorderKind.solidDouble) {
      final innerRadius = radius > 0 ? (radius - 2.0).clamp(0.0, radius) : 0.0;
      return Container(
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          border: Border.all(color: color, width: style.lineWidth),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Padding(
          padding: EdgeInsets.all(style.lineWidth + 2),
          child: Container(
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              border: Border.all(color: color, width: style.lineWidth),
              borderRadius: BorderRadius.circular(innerRadius),
            ),
            child: contentWithInsets,
          ),
        ),
      );
    }

    final Border? border = switch (style.kind) {
      AclBorderKind.solid => Border.all(color: color, width: style.lineWidth),
      AclBorderKind.top => Border(
        top: BorderSide(color: color, width: style.lineWidth),
      ),
      AclBorderKind.bottom => Border(
        bottom: BorderSide(color: color, width: style.lineWidth),
      ),
      AclBorderKind.left => Border(
        left: BorderSide(color: color, width: style.lineWidth),
      ),
      AclBorderKind.right => Border(
        right: BorderSide(color: color, width: style.lineWidth),
      ),
      AclBorderKind.horizontal => Border(
        top: BorderSide(color: color, width: style.lineWidth),
        bottom: BorderSide(color: color, width: style.lineWidth),
      ),
      AclBorderKind.vertical => Border(
        left: BorderSide(color: color, width: style.lineWidth),
        right: BorderSide(color: color, width: style.lineWidth),
      ),
      _ => null,
    };

    return Container(
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        border: border,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: contentWithInsets,
    );
  }

  // ── Auth-driven row / component elision ────────────────────────────────────

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
          keepers.add(comp.copyWithGapBefore(
            pendingGap,
            gapBeforeIsDefault: pendingGapIsDefault,
          ));
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

      final rowGap =
          inheritNextRowGap ? pendingRowGap : row.gapBefore;
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
      return (child as TomAuthorizable).effectiveAuthState ==
          TomAuthState.none;
    }
    return false;
  }

  // ── Content building ───────────────────────────────────────────────────────

  Widget _buildContent(BuildContext context) {
    final minContW =
        (widget.minimumContainerSize?.width ??
                widget.preferredContainerSize?.width ??
                0.0)
            .clamp(0.0, double.maxFinite);

    return LayoutBuilder(
      builder: (context, constraints) {
        final rawMaxW = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 0.0;
        final effectiveMaxW = math.max(rawMaxW, minContW);
        final canExpandHorizontally = effectiveMaxW > 0;
        final canExpandVertically = constraints.hasBoundedHeight;

        // ── Resolve effective rows (variants → inline → breakpoints) ────
        final variantRows = _selectVariantRows(
          canExpandHorizontally ? effectiveMaxW : null,
        );

        // Only resolve DeviceContext when inline variants exist (avoids
        // unnecessary MediaQuery/Theme subscriptions).
        final hasInlineVariants = variantRows.any(
          (r) => !r.isGapRow && r.components.any((c) => c.inlineVariant),
        );
        AclDeviceContext? deviceCtx;
        Acl? parentAcl;
        if (hasInlineVariants && canExpandHorizontally) {
          deviceCtx = AclDeviceContext.of(
            context,
            width: effectiveMaxW,
            height: canExpandVertically ? constraints.maxHeight : null,
          );
          parentAcl = context.findAncestorWidgetOfExactType<Acl>();
        }
        final inlineFilteredRows = _applyInlineVariants(
          variantRows,
          deviceCtx,
          parentAcl,
          context,
        );
        final breakpointedRows = _applyRowBreakpoints(
          inlineFilteredRows,
          canExpandHorizontally ? effectiveMaxW : null,
        );
        final effectiveRows = _applyMeasuredDefaultWidths(
          _applyAuthHiding(breakpointedRows),
        );

        final hasExpandY = effectiveRows.any(
          (row) => !row.isGapRow && row.components.any((c) => c.expandY),
        );
        final hasGapRows =
            effectiveRows.any((row) => row.isGapRow) && !widget.scrollableY;

        final useMaxVertical =
            (hasExpandY || hasGapRows) && canExpandVertically;
        final needsHorizontalScroll =
            !widget.scrollableX &&
            minContW > 0 &&
            constraints.hasBoundedWidth &&
            rawMaxW < minContW;

        // ── Pre-calculation loop ─────────────────────────────────────────
        final rowLayouts = _runPreCalcLoop(
          effectiveMaxW: canExpandHorizontally ? effectiveMaxW : null,
          overrideRows: effectiveRows,
        );

        // ── Global left overflow: uniform visual shift (Transform, not
        //    Padding) keeping everything inside the container without
        //    consuming layout space. ──────────────────────────────────────
        final globalMinHX = rowLayouts.isEmpty
            ? 0.0
            : rowLayouts.map((l) => l.minHorizontalX).reduce(math.min);
        final globalExtraLeft = globalMinHX < 0 ? -globalMinHX : 0.0;

        // ── Assemble Flutter widget tree from pre-computed values ────────
        final List<Widget> rowWidgets = [];
        int contentRowIndex = 0;
        final rowCanExpandVertically =
            canExpandVertically && !widget.scrollableY;

        for (final row in effectiveRows) {
          if (row.isGapRow) {
            if (!widget.scrollableY && canExpandVertically) {
              if (!hasExpandY) {
                // No expandY rows in layout: gap rows expand proportionally.
                final weight = (row.gapRowWeight * 1000).round().clamp(
                  1,
                  1000000,
                );
                final gapContent = row.separator != null
                    ? _buildSeparatorWidget(row.separator!)
                    : const SizedBox.expand();
                rowWidgets.add(
                  Flexible(flex: weight, fit: FlexFit.tight, child: gapContent),
                );
              } else {
                // expandY rows are present: gap rows do NOT compete for the
                // extra vertical space.
                if (row.separator != null) {
                  // Separator: at least 9px (4px pad + line + 4px pad),
                  // or the caller-specified minSize if larger.
                  final sepHeight = math.max(9.0, row.gapRowMinSize);
                  rowWidgets.add(
                    SizedBox(
                      height: sepHeight,
                      child: _buildSeparatorWidget(row.separator!),
                    ),
                  );
                } else if (row.gapRowMinSize > 0) {
                  // Pure spacing gap: collapse unless a minimum was specified.
                  rowWidgets.add(SizedBox(height: row.gapRowMinSize));
                }
              }
            } else {
              // Unbounded or scrollable context: gap rows cannot expand, but
              // still honour minSize as fixed spacing and render separators.
              if (row.separator != null) {
                final sepHeight = math.max(9.0, row.gapRowMinSize);
                rowWidgets.add(
                  SizedBox(
                    height: sepHeight,
                    child: _buildSeparatorWidget(row.separator!),
                  ),
                );
              } else if (row.gapRowMinSize > 0) {
                rowWidgets.add(SizedBox(height: row.gapRowMinSize));
              }
            }
            continue;
          }

          // Row policy gate. Independent of `hideUnauthorized`, which gates
          // `_applyAuthHiding` above — this one fires for any id'd row.
          // Because the `continue` precedes the gapBefore emission below, a
          // denied row takes its own gap with it and the next row keeps its
          // own; `_applyAuthHiding` does the opposite. See
          // `test/advanced_container_layout/acl_auth_visibility_test.dart`.
          TomAuthState? rowAuthState;
          if (row.id != null && row.id!.isNotEmpty) {
            final rowPath = _buildRowPolicyPath(
              rowId: row.id!,
              groupName: row.group,
            );
            rowAuthState = TomAuthorization.resolveAuth(rowPath);
            if (!rowAuthState.isVisible) {
              contentRowIndex++;
              continue;
            }
          }

          if (row.gapBefore > 0) {
            rowWidgets.add(SizedBox(height: row.gapBefore));
          }

          final layout = rowLayouts[contentRowIndex++];
          Widget builtRow = _buildRow(
            row: row,
            layout: layout,
            canExpandHorizontally: canExpandHorizontally,
            canExpandVertically: rowCanExpandVertically,
            availableWidth: canExpandHorizontally ? effectiveMaxW : null,
            rowAuthState: rowAuthState,
          );

          // Row IDs do not create new scopes - scoping is external to containers

          final resolvedRowHeight = aclResolveRowHeight(
            row,
            canExpandHorizontally ? effectiveMaxW : null,
          );
          if (resolvedRowHeight != null) {
            builtRow = SizedBox(height: resolvedRowHeight, child: builtRow);
          }

          rowWidgets.add(builtRow);
        }

        final columnMainAxisSize = widget.scrollableY || !useMaxVertical
            ? MainAxisSize.min
            : MainAxisSize.max;

        Widget column = Column(
          mainAxisSize: columnMainAxisSize,
          crossAxisAlignment: canExpandHorizontally
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.start,
          children: rowWidgets,
        );

        // Uniformly shift ALL rows right when any row overflows to the
        // left.  Transform.translate doesn't consume layout space, so
        // expandX / constraints stay correct.
        if (globalExtraLeft > 0) {
          column = Transform.translate(
            offset: Offset(globalExtraLeft, 0),
            child: column,
          );
        }

        if (!canExpandHorizontally) {
          column = UnconstrainedBox(
            alignment: Alignment.topLeft,
            child: column,
          );
        }

        if (needsHorizontalScroll) {
          column = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: SizedBox(width: minContW, child: column),
          );
        }

        if (widget.scrollableY) {
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: column,
          );
        }

        return column;
      },
    );
  }

  // ── Pre-calculation loop ──────────────────────────────────────────────────

  /// Runs the iterative pre-calculation loop and returns one [_AclRowLayout]
  /// per content row (gap rows are skipped).
  ///
  /// Uses only [_naturalSizeCache] as external input (no render-tree reads).
  /// Iterates up to [_maxPreCalcIterations] times until all values converge
  /// within [_geometryEpsilon].
  List<_AclRowLayout> _runPreCalcLoop({
    required double? effectiveMaxW,
    List<AclRow>? overrideRows,
  }) {
    final rows = overrideRows ?? widget.rows;
    final contentRows = rows.where((r) => !r.isGapRow).toList(growable: false);

    List<_AclRowLayout>? prev;

    for (int iter = 0; iter < _maxPreCalcIterations; iter++) {
      // Cross-row virtual rects accumulated as we process rows in order.
      final crossRowVirtualRects = <Key, Rect>{};
      // For Y-alignment we also need the virtual rects of same-row components
      // that were placed earlier in the row. These are local to each row pass
      // and built up inside _computeRowLayout.

      final current = <_AclRowLayout>[];
      for (final row in contentRows) {
        final layout = _computeRowLayout(
          row: row,
          availableWidth: effectiveMaxW,
          crossRowVirtualRects: crossRowVirtualRects,
        );
        // Publish this row's virtual rects for subsequent rows.
        crossRowVirtualRects.addAll(layout.virtualRects);
        current.add(layout);
      }

      if (prev != null && _hasConverged(prev, current)) {
        return current;
      }
      prev = current;
    }

    return prev!;
  }

  bool _hasConverged(List<_AclRowLayout> a, List<_AclRowLayout> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      final ra = a[i];
      final rb = b[i];
      if ((ra.estimatedHeight - rb.estimatedHeight).abs() >= _geometryEpsilon) {
        return false;
      }
      for (final entry in rb.fittedWidths.entries) {
        final prev = ra.fittedWidths[entry.key];
        if (prev == null || (prev - entry.value).abs() >= _geometryEpsilon) {
          return false;
        }
      }
      for (final entry in rb.horizontalDeltas.entries) {
        final prev = ra.horizontalDeltas[entry.key];
        if (prev == null || (prev - entry.value).abs() >= _geometryEpsilon) {
          return false;
        }
      }
      for (final entry in rb.verticalDeltas.entries) {
        final prev = ra.verticalDeltas[entry.key];
        if (prev == null || (prev - entry.value).abs() >= _geometryEpsilon) {
          return false;
        }
      }
    }
    return true;
  }

  /// Pure-Dart computation of layout values for one content row.
  _AclRowLayout _computeRowLayout({
    required AclRow row,
    required double? availableWidth,
    required Map<Key, Rect> crossRowVirtualRects,
  }) {
    final fittedWidths = <int, double>{};
    final horizontalDeltas = <int, double>{};
    final verticalDeltas = <int, double>{};
    final linkedWidths = <int, double>{};
    final linkedHeights = <int, double>{};
    final gapSlotWidths = <int, double>{};
    final virtualRects = <Key, Rect>{};

    // ── Phase 0: resolve linked sizes from sameWidthAs / sameHeightAs ────
    final hasGapSlots = row.components.any((c) => c.isGap);
    for (int i = 0; i < row.components.length; i++) {
      final comp = row.components[i];
      if (comp.useOtherDimX && comp.referenceKey != null) {
        final refRect = crossRowVirtualRects[comp.referenceKey];
        if (refRect != null) linkedWidths[i] = refRect.width;
      }
      if (comp.useOtherDimY && comp.referenceKey != null) {
        final refRect = crossRowVirtualRects[comp.referenceKey];
        if (refRect != null) linkedHeights[i] = refRect.height;
      }
    }

    // ── Phase 1/2/3: compute fitted widths ───────────────────────────────
    if (availableWidth != null && availableWidth.isFinite) {
      final fw = _computeFittedWidths(
        row: row,
        availableWidth: availableWidth,
        crossRowVirtualRects: crossRowVirtualRects,
        linkedWidths: linkedWidths,
      );
      if (fw != null) fittedWidths.addAll(fw);
    }

    // ── Gap slot widths ───────────────────────────────────────────────────
    if (hasGapSlots && availableWidth != null && availableWidth.isFinite) {
      double totalFitted = 0;
      for (int i = 0; i < row.components.length; i++) {
        final comp = row.components[i];
        if (comp.isGap) continue;
        totalFitted +=
            fittedWidths[i] ??
            linkedWidths[i] ??
            comp.preferredSize?.width ??
            _naturalWidth(comp) ??
            0;
      }
      final gapRemaining = math.max(0.0, availableWidth - totalFitted);
      final gapWeightSum = row.components
          .where((c) => c.isGap)
          .fold(0.0, (s, c) => s + c.gapWeight);
      if (gapWeightSum > 0 && !widget.scrollableX) {
        for (int i = 0; i < row.components.length; i++) {
          final comp = row.components[i];
          if (!comp.isGap) continue;
          gapSlotWidths[i] = (gapRemaining * comp.gapWeight / gapWeightSum)
              .clamp(0.0, double.infinity);
        }
      }
    }

    // ── Build virtual rects and compute alignment deltas ──────────────────

    // Pre-compute expandX allocations so that virtual rects for non-expandX
    // components positioned AFTER an expandX component use the correct X
    // offsets.  Without this, cross-row alignRightToRight references to
    // components on the right of an expandX field would see the preferred
    // width instead of the actual expanded width, producing wrong deltas.
    //
    // Skip the expandX surplus-distribution entirely when the shrink phase
    // has already produced fitted widths for expandX components (row is
    // narrower than natural) — they're shrinking proportionally toward
    // their minimum via `fittedWidths`, not growing.
    final rowIsShrinking = row.components.any(
      (c) => c.expandX && !c.isGap && fittedWidths.containsKey(
            row.components.indexOf(c),
          ),
    );
    final expandXWidths = <int, double>{};
    if (!rowIsShrinking &&
        availableWidth != null && availableWidth.isFinite) {
      double fixedWidth = 0;
      double totalExpandXFlex = 0;
      final expandXCompIndices = <int>[];
      final expandXFlexes = <int, double>{};
      for (int i = 0; i < row.components.length; i++) {
        final comp = row.components[i];
        if (comp.isGap) {
          fixedWidth += gapSlotWidths[i] ?? 0;
          continue;
        }
        if (comp.expandX && !comp.isGap) {
          // expandX components share the surplus left over after every
          // non-expandX component has taken its preferred width. Their
          // flex weight mirrors the non-expandX grow phase: (P/M − 1)
          // when both M and P are explicitly set with min < pref, or a
          // small positive fallback so callers who just mark expandX
          // without also configuring M/P still participate in the row.
          final minW =
              (comp.minimumSize?.width ?? linkedWidths[i] ?? 0)
                  .clamp(0.0, double.maxFinite);
          final prefW =
              (fittedWidths[i] ?? comp.preferredSize?.width ?? minW)
                  .clamp(minW, double.maxFinite);
          double flex;
          if (minW > 0 && prefW > minW) {
            flex = prefW / minW - 1.0;
          } else {
            // Symmetric fallback: when M is unset or M >= P the caller
            // hasn't asked for proportional growth, so every expandX
            // component takes an equal share of whatever surplus exists.
            flex = 1.0;
          }
          flex = (flex.isFinite ? flex : 1.0).clamp(1e-3, 10000.0);
          expandXFlexes[i] = flex;
          expandXCompIndices.add(i);
          totalExpandXFlex += flex;
          // Count the preferred width as the minimum allocation.
          fixedWidth += aclEffectiveGapBefore(comp, row, availableWidth);
        } else {
          final w = fittedWidths[i] ??
              linkedWidths[i] ??
              comp.preferredSize?.width ??
              _naturalWidth(comp) ??
              0;
          fixedWidth += w + aclEffectiveGapBefore(comp, row, availableWidth);
        }
      }
      if (expandXCompIndices.isNotEmpty && totalExpandXFlex > 0) {
        final expandPool = math.max(0.0, availableWidth - fixedWidth);
        for (final i in expandXCompIndices) {
          final share = expandPool * (expandXFlexes[i]! / totalExpandXFlex);
          expandXWidths[i] = share.clamp(0.0, double.maxFinite);
        }
      }
    }

    double plannedX = 0;
    double maxHorizontalX = 0;
    double minHorizontalX = 0;
    double rowEstimatedHeight = 0;
    // Same-row virtual rects needed for Y-alignment back-references.
    final sameRowVirtualRects = <Key, Rect>{};

    for (int i = 0; i < row.components.length; i++) {
      final comp = row.components[i];

      if (comp.isGap) {
        plannedX += gapSlotWidths[i] ?? 0;
        maxHorizontalX = math.max(maxHorizontalX, plannedX);
        continue;
      }

      final isFlexNative =
          comp.child is Flexible ||
          comp.child is Expanded ||
          comp.child is Spacer;

      final hasExplicitXAlignment = comp.alignXToKey != null;

      // Check collapseToVisual BEFORE advancing by gapBefore so that explicit
      // gaps (dist:) are never cancelled. When collapsing, the component ends
      // up at (maxHX + gapBefore) — flush with the previous component's visual
      // right edge, plus the requested gap. Both pre-calc and _buildRow emit
      // SizedBox(gapBefore) first, then apply hDelta as a spacer or Transform,
      // so they remain in sync.
      double hDelta = 0;
      final priorPlannedX = plannedX;
      final compEffectiveGap = aclEffectiveGapBefore(comp, row, availableWidth);
      if (compEffectiveGap > 0) {
        plannedX += compEffectiveGap;
      }

      final linkedW = linkedWidths[i];
      final linkedH = linkedHeights[i];

      // Horizontal alignment delta
      if (!isFlexNative &&
          !hasExplicitXAlignment &&
          maxHorizontalX < priorPlannedX) {
        // collapseToVisual: maxHX lags behind the natural planned position.
        // Place component at maxHX + gapBefore by using priorPlannedX as base.
        hDelta = maxHorizontalX - priorPlannedX;
      } else if (hasExplicitXAlignment) {
        // For components with explicit X alignment in rows that do not fill
        // the available width, _buildRow wraps every child with
        // ConstrainedBox(maxWidth: constraints.maxWidth). The actual rendered
        // width is therefore min(preferredWidth, containerWidth). Feed the same
        // effective width into _calcHorizontalDelta so the centre point is right.
        final rowFillsWidth = row.components.any(
          (c) => (c.expandX && !c.isGap) || c.isGap,
        );
        double? alignLinkedW = linkedW;
        if (!rowFillsWidth &&
            alignLinkedW == null &&
            availableWidth != null &&
            availableWidth.isFinite) {
          final pref = comp.preferredSize?.width;
          if (pref != null && pref > availableWidth) {
            alignLinkedW = availableWidth;
          }
        }
        hDelta = _calcHorizontalDelta(
          comp: comp,
          plannedX: plannedX,
          linkedWidth: alignLinkedW,
          virtualRects: sameRowVirtualRects,
          crossRowVirtualRects: crossRowVirtualRects,
          fittedWidths: fittedWidths,
        );
      }
      horizontalDeltas[i] = hDelta;

      // For expandX components, use the pre-computed expanded width so that
      // subsequent components (and cross-row references) see correct offsets.
      final estimatedW = expandXWidths[i] ??
          _estimateW(comp, linkedW, fittedWidths[i]);
      final estimatedH = _estimateH(comp, linkedH);

      rowEstimatedHeight = math.max(rowEstimatedHeight, estimatedH);

      final shiftedLeft = plannedX + (hDelta < 0 ? hDelta : 0);
      final shiftedRight = shiftedLeft + estimatedW;
      minHorizontalX = math.min(minHorizontalX, shiftedLeft);
      maxHorizontalX = math.max(maxHorizontalX, shiftedRight);

      final key = comp.componentKey;
      if (key != null) {
        final vRect = Rect.fromLTWH(shiftedLeft, 0, estimatedW, estimatedH);
        virtualRects[key] = vRect;
        sameRowVirtualRects[key] = vRect;
      }

      plannedX += (hDelta > 0 ? hDelta : 0) + estimatedW;
    }

    // ── Vertical alignment deltas (same-row) ─────────────────────────────
    // Requires virtual rects to be built first; update them with Y offsets.
    //
    // Virtual rects all have top=0. _buildRow places each non-expandY
    // component at a baseTopInRow that depends on the Row's actual
    // crossAxisAlignment — which in turn comes from
    // row.defaultRowCrossAlignment (top / center / bottom). Adjust the
    // virtual rect Y by that default offset so the delta reflects a
    // shift from the component's rendered baseline position, not from
    // an artificial top=0 or a hardcoded centering assumption.
    final hasRowExpandY = row.components.any((c) => !c.isGap && c.expandY);
    // Per-component rowCrossAlignment lookup: only meaningful when the
    // row is stretched (hasRowExpandY), otherwise every child ends up
    // aligned by the Row's single crossAxisAlignment regardless of the
    // component's own setting — see _wrapWithRowCrossAlignment.
    final keyToComp = <Key, AclComponent>{};
    for (final c in row.components) {
      if (c.componentKey != null) keyToComp[c.componentKey!] = c;
    }
    double defaultTopFor(Rect r, AclComponent? c) {
      if (hasRowExpandY) {
        // Stretch row: the Align wrapper fills row height and the
        // component sits at its own rowCrossAlignment inside that.
        final align = c?.rowCrossAlignment ?? AclRowCrossAlignment.top;
        return switch (align) {
          AclRowCrossAlignment.top => 0.0,
          AclRowCrossAlignment.center => (rowEstimatedHeight - r.height) / 2,
          AclRowCrossAlignment.bottom => rowEstimatedHeight - r.height,
        };
      }
      // Fixed-crossAxis row: Row.crossAxisAlignment dictates placement,
      // not the component's own alignment.
      return switch (row.defaultRowCrossAlignment) {
        AclRowCrossAlignment.top => 0.0,
        AclRowCrossAlignment.center => (rowEstimatedHeight - r.height) / 2,
        AclRowCrossAlignment.bottom => rowEstimatedHeight - r.height,
      };
    }

    for (int i = 0; i < row.components.length; i++) {
      final comp = row.components[i];
      if (comp.alignYToKey == null ||
          comp.alignYFrom == null ||
          comp.alignYTo == null ||
          comp.componentKey == null) {
        continue;
      }

      final selfRect = virtualRects[comp.componentKey];
      final refRect =
          sameRowVirtualRects[comp.alignYToKey] ??
          virtualRects[comp.alignYToKey];
      if (selfRect == null || refRect == null) continue;

      final refComp = keyToComp[comp.alignYToKey];

      final adjSelfRect = selfRect.translate(0, defaultTopFor(selfRect, comp));
      final adjRefRect = refRect.translate(0, defaultTopFor(refRect, refComp));

      final selfPoint = _verticalPoint(adjSelfRect, comp.alignYFrom!);
      final refPoint = _verticalPoint(adjRefRect, comp.alignYTo!);
      // Gap convention: positive gap always pushes self further AWAY from
      // the reference edge; negative gap pulls it in (overlap). The sign
      // therefore depends on which side of the reference self lands on.
      //   self.top  → ref.bottom : self is below → +gap pushes down
      //   self.bottom → ref.top : self is above → +gap pushes up
      //   same-ordinal alignments (e.g. TopToTop) preserve the historical
      //   -gap convention so existing call-sites keep behaving the same.
      final signedGap =
          _gapSignY(comp.alignYFrom!, comp.alignYTo!) * comp.alignYGap;
      final delta = (refPoint + signedGap) - selfPoint;
      verticalDeltas[i] = delta;
    }

    return _AclRowLayout(
      fittedWidths: fittedWidths,
      horizontalDeltas: horizontalDeltas,
      verticalDeltas: verticalDeltas,
      linkedWidths: linkedWidths,
      linkedHeights: linkedHeights,
      gapSlotWidths: gapSlotWidths,
      virtualRects: virtualRects,
      estimatedHeight: rowEstimatedHeight,
      minHorizontalX: minHorizontalX,
    );
  }

  // ── Natural size helpers ──────────────────────────────────────────────────

  double? _naturalWidth(AclComponent comp) {
    final key = comp.componentKey;
    if (key == null) return null;
    return _naturalSizeCache[key]?.width ??
        (comp.child is SizedBox ? (comp.child as SizedBox).width : null);
  }

  double? _naturalHeight(AclComponent comp) {
    final key = comp.componentKey;
    if (key == null) return null;
    return _naturalSizeCache[key]?.height;
  }

  double _estimateW(
    AclComponent comp,
    double? linkedWidth,
    double? fittedWidth,
  ) {
    if (fittedWidth != null) return fittedWidth.clamp(0, double.infinity);
    if (linkedWidth != null) return linkedWidth.clamp(0, double.infinity);
    return (comp.preferredSize?.width ??
            comp.minimumSize?.width ??
            _naturalWidth(comp) ??
            0)
        .clamp(0, double.infinity);
  }

  double _estimateH(AclComponent comp, double? linkedHeight) {
    if (linkedHeight != null && linkedHeight > 0) {
      return linkedHeight.clamp(0, double.infinity);
    }
    // Treat preferredSize.height == 0 as "no preference" so the natural
    // height is used.  The auto-default Size(150, 0) must not suppress
    // intrinsic height for labels and other unsized components.
    final prefH = comp.preferredSize?.height;
    if (prefH != null && prefH > 0) return prefH;
    return (comp.minimumSize?.height ??
            _naturalHeight(comp) ??
            0)
        .clamp(0, double.infinity);
  }

  // ── Horizontal delta (pure Dart) ──────────────────────────────────────────

  double _calcHorizontalDelta({
    required AclComponent comp,
    required double plannedX,
    required double? linkedWidth,
    required Map<Key, Rect> virtualRects,
    required Map<Key, Rect> crossRowVirtualRects,
    required Map<int, double> fittedWidths,
  }) {
    if (comp.alignXToKey == null ||
        comp.alignXFrom == null ||
        comp.alignXTo == null) {
      return 0;
    }

    final key = comp.alignXToKey!;
    final refRect = crossRowVirtualRects[key] ?? virtualRects[key];
    if (refRect == null) return 0;

    final widthEstimate =
        linkedWidth ??
        (comp.preferredSize?.width ??
            comp.minimumSize?.width ??
            _naturalWidth(comp) ??
            0);
    final selfPoint =
        plannedX + _horizontalOffset(comp.alignXFrom!, widthEstimate);
    final targetPoint = _horizontalPoint(refRect, comp.alignXTo!);
    // See _gapSignY for the convention — mirrored on the X axis:
    //   self.left → ref.right : self is right of ref → +gap pushes right
    //   self.right → ref.left : self is left of ref → +gap pushes left
    //   same-ordinal alignments keep the historical -gap convention.
    final signedGap = _gapSignX(comp.alignXFrom!, comp.alignXTo!) * comp.alignXGap;
    return (targetPoint + signedGap) - selfPoint;
  }

  Widget _buildSeparatorWidget(AclSeparator separator) {
    return LayoutBuilder(
      builder: (context, _) {
        final theme = Theme.of(context);
        final lineColor = separator.color ?? theme.dividerColor;
        Widget line = Container(height: separator.lineWidth, color: lineColor);

        Widget content;
        if (separator.style == AclSeparatorStyle.doubleLine) {
          content = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              line,
              SizedBox(height: separator.lineWidth * 2),
              Container(height: separator.lineWidth, color: lineColor),
            ],
          );
        } else {
          content = line;
        }

        final alignment = switch (separator.alignment) {
          AclSeparatorAlignment.top => Alignment.topCenter,
          AclSeparatorAlignment.middle => Alignment.center,
          AclSeparatorAlignment.bottom => Alignment.bottomCenter,
        };

        return Align(alignment: alignment, child: content);
      },
    );
  }

  // ── Row widget assembly (Flutter tree only — all values pre-computed) ───────

  Widget _buildRow({
    required AclRow row,
    required _AclRowLayout layout,
    required bool canExpandHorizontally,
    required bool canExpandVertically,
    double? availableWidth,
    TomAuthState? rowAuthState,
  }) {
    final isRtl =
        (widget.direction ??
            AclDirectionScope.maybeOf(context) ??
            AclDirection.ltr) ==
        AclDirection.rtl;
    final mainAxisAlignment = switch (row.alignment) {
      RowAlignment.left => MainAxisAlignment.start,
      RowAlignment.center => MainAxisAlignment.center,
      RowAlignment.right => MainAxisAlignment.end,
    };

    final hasExpandX = row.components.any((c) => c.expandX && !c.isGap);
    final hasExpandY = row.components.any((c) => c.expandY);
    final hasGapSlots = row.components.any((c) => c.isGap);
    final rowFillsWidth = hasExpandX || hasGapSlots;

    final gapWeightSum = hasGapSlots
        ? row.components
              .where((c) => c.isGap)
              .fold(0.0, (s, c) => s + c.gapWeight)
        : 0.0;

    final children = <Widget>[];
    double plannedX = 0;
    double minHorizontalX = 0;
    double maxHorizontalX = 0;
    double rowEstimatedWidth = 0;
    double minVerticalOffset = 0;
    double maxVerticalExtent = 0;
    final rowEstimatedHeight = layout.estimatedHeight;
    int componentIndex = -1;

    for (final component in row.components) {
      componentIndex++;

      // ── Gap slot ──────────────────────────────────────────────────────────
      if (component.isGap) {
        if (!widget.scrollableX && gapWeightSum > 0) {
          if (rowFillsWidth) {
            final totalExpandXFlex = hasExpandX
                ? row.components.where((c) => c.expandX && !c.isGap).fold(0.0, (
                    s,
                    c,
                  ) {
                    final pref = c.preferredSize?.width ?? 0.0;
                    final min = c.minimumSize?.width ?? 0.0;
                    final diff = pref - min;
                    return s + (diff > 0 && diff.isFinite ? diff : 1000.0);
                  })
                : 0.0;
            final int flex;
            if (totalExpandXFlex > 0) {
              flex = ((component.gapWeight / gapWeightSum) * totalExpandXFlex)
                  .round()
                  .clamp(1, 100000);
            } else {
              flex = (component.gapWeight / gapWeightSum * 10000).round().clamp(
                1,
                10000,
              );
            }
            children.add(Spacer(flex: flex));
          } else {
            final gapWidth = (layout.gapSlotWidths[componentIndex] ?? 0).clamp(
              0.0,
              double.infinity,
            );
            if (gapWidth > 0) children.add(SizedBox(width: gapWidth));
            plannedX += gapWidth;
            maxHorizontalX = math.max(maxHorizontalX, plannedX);
          }
        }
        continue;
      }

      // ── Regular component ─────────────────────────────────────────────────
      final isFlexNativeChild =
          component.child is Flexible ||
          component.child is Expanded ||
          component.child is Spacer;

      final alignmentDelta = layout.horizontalDeltas[componentIndex] ?? 0.0;
      final verticalAlignmentOffset =
          layout.verticalDeltas[componentIndex] ?? 0.0;

      // Always emit gapBefore — the pre-calc always accounts for it in plannedX
      // so the alignmentDelta is always measured from after the gap.
      final renderGap = aclEffectiveGapBefore(component, row, availableWidth);
      if (renderGap > 0) {
        children.add(SizedBox(width: renderGap));
        plannedX += renderGap;
      }

      if (alignmentDelta > 0) {
        children.add(SizedBox(width: alignmentDelta));
        plannedX += alignmentDelta;
      }

      Widget child = component.child;

      // ── Group visibility ──────────────────────────────────────────────────
      final compGroup = component.group ?? row.group;
      final visMode = _groupMode(compGroup);
      if (visMode == AclGroupVisibilityMode.hidden) {
        // Hidden: zero size, skip the component entirely.
        children.add(const SizedBox.shrink());
        continue;
      }

      // Component policy gate. Like the row gate, independent of
      // `hideUnauthorized`. `renderGap` above has already been emitted by the
      // time we get here, and the next component emits its own, so a denied
      // component reclaims its width and leaves *both* gaps — the mirror of
      // `_applyAuthHiding`, which forwards one gap and drops the other.
      String? componentPolicyPath;
      TomAuthState? authState;
      if (component.id != null && component.id!.isNotEmpty) {
        componentPolicyPath = _buildComponentPolicyPath(
          componentId: component.id!,
          groupName: compGroup,
          row: row,
        );
        authState = TomAuthorization.resolveAuth(componentPolicyPath);
        if (!authState.isVisible) {
          children.add(const SizedBox.shrink());
          continue;
        }
      }

      // Wrap with AclScope to provide ID/group metadata.
      child = _wrapWithScope(
        child,
        component,
        row,
        groupName: compGroup,
        fullPath: componentPolicyPath,
      );

      if (rowAuthState == TomAuthState.read || authState == TomAuthState.read) {
        final style = TomThemeScope.readonlyStyleOf(context);
        child = style.apply(child);
      }

      // Apply disabled treatment if needed.
      if (visMode == AclGroupVisibilityMode.disabled) {
        child = IgnorePointer(child: Opacity(opacity: 0.4, child: child));
      }

      // ── Auto-defaulted width: measure, and never overflow ────────────────
      // Innermost wrapper, so it sees the component's own content and receives
      // whatever width the sizing wrappers below settle on. Only components
      // whose preferred width the builder invented get it; an author-declared
      // width is emitted exactly as before.
      if (!isFlexNativeChild &&
          component.preferredWidthIsDefault &&
          component.componentKey != null) {
        final measureKey = component.componentKey!;
        child = _AclFloorWidthBox(
          onMinWidth: (minWidth) =>
              _reportMeasuredDefaultWidth(measureKey, minWidth),
          child: child,
        );
      }

      final linkedWidth = layout.linkedWidths[componentIndex];
      final linkedHeight = layout.linkedHeights[componentIndex];
      final fittedWidth = layout.fittedWidths[componentIndex];

      final minWidth = component.useOtherDimX
          ? (linkedWidth ??
                component.minimumSize?.width ??
                component.preferredSize?.width)
          : (component.minimumSize?.width ?? component.preferredSize?.width);
      final safePrefH = (component.preferredSize?.height != null &&
              component.preferredSize!.height > 0)
          ? component.preferredSize!.height
          : null;
      final minHeight = component.useOtherDimY
          ? ((linkedHeight != null && linkedHeight > 0 ? linkedHeight : null) ??
                component.minimumSize?.height ??
                safePrefH)
          : (component.minimumSize?.height ?? safePrefH);
      // For useOtherDimX components whose reference is not yet resolved (first frame),
      // fall back to availableWidth as maxWidth — prevents TextField/Dropdown
      // "unbounded width" assertion inside Row(mainAxisSize.max) rows.
      final maxWidth = component.useOtherDimX
          ? (linkedWidth ??
                component.maximumSize?.width ??
                (availableWidth?.isFinite == true ? availableWidth : null))
          : component.maximumSize?.width;
      // Skip linkedHeight of 0 for maxHeight — on the first frame the
      // reference component may have height 0 (auto-default Size(150,0))
      // and constraining sameHeightAs followers to maxHeight:0 would collapse
      // them.  After the natural-size cache populates, linkedHeight becomes
      // the real rendered height and the constraint is correct.
      final maxHeight = component.useOtherDimY
          ? ((linkedHeight != null && linkedHeight > 0
                  ? linkedHeight
                  : null) ??
              component.maximumSize?.height)
          : component.maximumSize?.height;

      if (!isFlexNativeChild &&
          (minWidth != null ||
              minHeight != null ||
              maxWidth != null ||
              maxHeight != null)) {
        child = ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: minWidth ?? 0,
            minHeight: minHeight ?? 0,
            maxWidth: maxWidth ?? double.infinity,
            maxHeight: maxHeight ?? double.infinity,
          ),
          child: child,
        );
      }

      // ── Height wrapping (BEFORE width) ──────────────────────────────────
      // Height wrapping is applied first so that the width SizedBox ends up
      // on the outside.  This is critical for vertical centering: the inner
      // Column(CrossAxisAlignment.stretch) inherits the tight width
      // constraint from the outer SizedBox(width:), preserving correct
      // widths for both expandX and non-expandX components.
      if (!isFlexNativeChild && (!component.expandY || !canExpandVertically)) {
        // Treat preferredSize.height == 0 as "no height preference" so that
        // auto-defaulted components use intrinsic height instead of being
        // constrained to 0.
        final rawPrefH = component.preferredSize?.height;
        final effectiveHeight =
            (linkedHeight != null && linkedHeight > 0 ? linkedHeight : null) ??
            (rawPrefH != null && rawPrefH > 0 ? rawPrefH : null);
        if (effectiveHeight != null) {
          // For expandX components, do NOT wrap with Column(stretch) — it
          // would override the ConstrainedBox's maxWidth since the Align
          // layers above loosen the Flexible's tight constraint, and
          // Column(stretch) re-tightens to whatever its parent gives.
          // Non-expandX components have an outer SizedBox(width:) that
          // supplies the correct tight width for Column(stretch).
          if (component.expandX && canExpandHorizontally) {
            child = SizedBox(height: effectiveHeight, child: child);
          } else {
            // Vertically centre content inside the allocated height.
            // Column with CrossAxisAlignment.stretch preserves the parent's
            // tight width constraint from the outer SizedBox(width:).
            // Flexible(loose) prevents the child from exceeding the Column's
            // height when the inner ConstrainedBox has a larger maxHeight.
            final verticalAlign = switch (component.rowCrossAlignment) {
              AclRowCrossAlignment.top => MainAxisAlignment.start,
              AclRowCrossAlignment.center => MainAxisAlignment.center,
              AclRowCrossAlignment.bottom => MainAxisAlignment.end,
            };
            child = SizedBox(
              height: effectiveHeight,
              child: Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: verticalAlign,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [Flexible(child: child)],
              ),
            );
          }
        }
      }

      // ── Width wrapping (OUTSIDE height) ─────────────────────────────────
      // When fittedWidth is set for an expandX component, the shrink
      // phase has decided that component's width — we must respect it
      // (in particular the minimumSize floor) instead of handing the
      // rest of this method's expandX-only path over to Flexible, which
      // would pull the component below its minimum whenever the row is
      // tighter than the sum of shrunken widths.
      final expandXShrinking = component.expandX &&
          canExpandHorizontally &&
          fittedWidth != null;
      if (!isFlexNativeChild &&
          (!component.expandX || !canExpandHorizontally || expandXShrinking)) {
        final effectiveWidth =
            fittedWidth ?? linkedWidth ?? component.preferredSize?.width;
        if (effectiveWidth != null) {
          child = SizedBox(width: effectiveWidth, child: child);
        }
      }

      final hasFiniteMaxWidth =
          (component.maximumSize?.width ?? double.infinity).isFinite;
      if (!isFlexNativeChild &&
          component.expandX &&
          canExpandHorizontally &&
          !expandXShrinking &&
          !hasFiniteMaxWidth) {
        child = SizedBox(width: double.infinity, child: child);
      }

      final estimatedWidth = _estimateW(component, linkedWidth, fittedWidth);
      final estimatedHeight = _estimateH(component, linkedHeight);

      final shiftedLeftInRow =
          plannedX + (alignmentDelta < 0 ? alignmentDelta : 0);
      final shiftedRightInRow = shiftedLeftInRow + estimatedWidth;
      minHorizontalX = math.min(minHorizontalX, shiftedLeftInRow);
      maxHorizontalX = math.max(maxHorizontalX, shiftedRightInRow);
      rowEstimatedWidth = math.max(
        rowEstimatedWidth,
        plannedX + estimatedWidth,
      );

      // NOTE: componentKey wrapping is now done AFTER transforms to ensure
      // getRect() returns the visually transformed position.

      // Skip cross-alignment wrapping for expandY components — they are
      // stretched by CrossAxisAlignment.stretch and must not have their
      // height constraints loosened by an Align(heightFactor:1) wrapper.
      if (!isFlexNativeChild && !(component.expandY && canExpandVertically)) {
        child = _wrapWithRowCrossAlignment(child, component.rowCrossAlignment);
      }

      if (!isFlexNativeChild && alignmentDelta < 0) {
        child = Transform.translate(
          offset: Offset(alignmentDelta, 0),
          child: child,
        );
      }

      // baseTopInRow must match where the Row widget actually places the
      // component cross-axis. With CrossAxisAlignment.stretch (hasExpandY
      // path), every child starts at y=0 and fills the row height. Without
      // expandY, the Row's crossAxisAlignment is driven by the row's
      // configured defaultRowCrossAlignment (top/center/bottom) — NOT a
      // hardcoded centering — otherwise the min/maxVerticalExtent that
      // drive Padding(top/bottom) over-/under-estimate the space needed
      // around translated components.
      final double baseTopInRow;
      if (hasExpandY && canExpandVertically) {
        baseTopInRow = 0.0;
      } else {
        baseTopInRow = switch (row.defaultRowCrossAlignment) {
          AclRowCrossAlignment.top => 0.0,
          AclRowCrossAlignment.center =>
              (rowEstimatedHeight - estimatedHeight) / 2,
          AclRowCrossAlignment.bottom =>
              rowEstimatedHeight - estimatedHeight,
        };
      }
      final shiftedTopInRow = baseTopInRow + verticalAlignmentOffset;
      final shiftedBottomInRow = shiftedTopInRow + estimatedHeight;

      minVerticalOffset = math.min(minVerticalOffset, shiftedTopInRow);
      maxVerticalExtent = math.max(maxVerticalExtent, shiftedBottomInRow);

      if (!isFlexNativeChild && verticalAlignmentOffset != 0) {
        child = Transform.translate(
          offset: Offset(0, verticalAlignmentOffset),
          child: child,
        );
      }

      // Wrap with componentKey AFTER transforms so getRect() sees final position.
      if (!isFlexNativeChild && component.componentKey != null) {
        if (component.expandY && canExpandVertically) {
          // expandY: use a transparent SizedBox to carry the key without
          // loosening the cross-axis (height) constraints that allow this
          // component to fill the row.
          child = SizedBox(key: component.componentKey, child: child);
        } else {
          child = Align(
            key: component.componentKey,
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            heightFactor: 1,
            child: child,
          );
        }
      }

      if (component.expandX && canExpandHorizontally && !expandXShrinking) {
        // Use isFlexNativeChild (checked on component.child) since `child`
        // may have been wrapped with AclScope and other widgets by now.
        if (!isFlexNativeChild) {
          final minW = (component.minimumSize?.width ?? linkedWidth ?? 0).clamp(
            0.0,
            double.maxFinite,
          );
          final prefW = (fittedWidth ?? component.preferredSize?.width ?? minW)
              .clamp(minW, double.maxFinite);
          final diff = prefW - minW;
          final flexWeight = (diff.isFinite ? diff.round() : 1000).clamp(
            1,
            10000,
          );
          child = Flexible(flex: flexWeight, fit: FlexFit.tight, child: child);
        }
      }

      children.add(child);
      plannedX += estimatedWidth;
    }

    // ── Row widget assembly ───────────────────────────────────────────────────

    Widget rowWidget;
    // No per-row horizontal compensation — cross-row alignment requires
    // all rows to share the same coordinate origin.  A global
    // Transform.translate on the containing Column handles left overflow.
    final double extraLeft = 0.0;

    if (!rowFillsWidth && canExpandHorizontally) {
      rowWidget = LayoutBuilder(
        builder: (context, constraints) {
          final boundedChildren = children
              .map(
                (child) => child is Flexible || child is Spacer
                    ? child
                    : ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth,
                        ),
                        child: child,
                      ),
              )
              .toList();

          final rowContent = Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: _resolveRowCrossAxis(
              row.defaultRowCrossAlignment,
              hasExpandY: hasExpandY,
              canExpandVertically: canExpandVertically,
            ),
            mainAxisSize: MainAxisSize.min,
            children: boundedChildren,
          );

          final alignment = switch (mainAxisAlignment) {
            MainAxisAlignment.end ||
            MainAxisAlignment.spaceBetween ||
            MainAxisAlignment.spaceAround ||
            MainAxisAlignment.spaceEvenly => AlignmentDirectional.centerEnd,
            MainAxisAlignment.center => Alignment.center,
            _ => AlignmentDirectional.centerStart,
          };

          return widget.scrollableX
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  child: rowContent,
                )
              : Align(alignment: alignment, child: rowContent);
        },
      );
    } else {
      rowWidget = Row(
        mainAxisAlignment: hasGapSlots
            ? MainAxisAlignment.start
            : mainAxisAlignment,
        crossAxisAlignment: _resolveRowCrossAxis(
          row.defaultRowCrossAlignment,
          hasExpandY: hasExpandY,
          canExpandVertically: canExpandVertically,
        ),
        mainAxisSize: rowFillsWidth && canExpandHorizontally
            ? MainAxisSize.max
            : MainAxisSize.min,
        children: children,
      );
    }

    final double extraTop = minVerticalOffset < 0 ? -minVerticalOffset : 0.0;
    final extraBottom = math.max(0.0, maxVerticalExtent - rowEstimatedHeight);
    final extraRight = rowFillsWidth && canExpandHorizontally
        ? 0.0
        : math.max(0.0, maxHorizontalX - rowEstimatedWidth);
    if (extraTop > 0 || extraBottom > 0 || extraLeft > 0 || extraRight > 0) {
      rowWidget = Padding(
        padding: EdgeInsets.only(
          left: extraLeft,
          right: extraRight,
          top: extraTop,
          bottom: extraBottom,
        ),
        child: rowWidget,
      );
    }

    if (!rowFillsWidth && canExpandHorizontally && extraLeft > 0) {
      rowWidget = ClipRect(child: rowWidget);
    }

    // Wrap with an explicit Directionality rather than inheriting the
    // ambient one, so the resolved AclDirection controls component flow even
    // when it opposes the surrounding app.
    rowWidget = Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: rowWidget,
    );

    if (hasExpandY && canExpandVertically) {
      int rowFlex = 1;
      for (final component in row.components) {
        if (!component.expandY) continue;
        final linkedH = layout.linkedHeights[row.components.indexOf(component)];
        final minH = (component.minimumSize?.height ?? linkedH ?? 0).clamp(
          0,
          double.infinity,
        );
        final prefH = (component.preferredSize?.height ?? minH).clamp(
          minH,
          double.infinity,
        );
        rowFlex = (rowFlex + (prefH - minH).round()).clamp(1, 10000);
      }
      return Flexible(flex: rowFlex, fit: FlexFit.tight, child: rowWidget);
    }

    return rowWidget;
  }

  Widget _wrapWithRowCrossAlignment(
    Widget child,
    AclRowCrossAlignment rowCrossAlignment,
  ) {
    final alignment = switch (rowCrossAlignment) {
      AclRowCrossAlignment.top => Alignment.topCenter,
      AclRowCrossAlignment.center => Alignment.center,
      AclRowCrossAlignment.bottom => Alignment.bottomCenter,
    };
    return Align(
      alignment: alignment,
      widthFactor: 1,
      heightFactor: 1,
      child: child,
    );
  }

  /// Maps a row's default [AclRowCrossAlignment] onto the matching
  /// Flutter [CrossAxisAlignment] for the Row widget. When the row has
  /// any expandY component whose vertical grow is active, we stretch so
  /// those components can fill the row's height; otherwise honour the
  /// row's configured alignment (top / center / bottom).
  CrossAxisAlignment _resolveRowCrossAxis(
    AclRowCrossAlignment rowDefault, {
    required bool hasExpandY,
    required bool canExpandVertically,
  }) {
    if (hasExpandY && canExpandVertically) {
      return CrossAxisAlignment.stretch;
    }
    return switch (rowDefault) {
      AclRowCrossAlignment.top => CrossAxisAlignment.start,
      AclRowCrossAlignment.center => CrossAxisAlignment.center,
      AclRowCrossAlignment.bottom => CrossAxisAlignment.end,
    };
  }

  double _horizontalPoint(Rect rect, AclAxisPointX point) => switch (point) {
    AclAxisPointX.left => rect.left,
    AclAxisPointX.center => rect.center.dx,
    AclAxisPointX.right => rect.right,
  };

  double _verticalPoint(Rect rect, AclAxisPointY point) => switch (point) {
    AclAxisPointY.top => rect.top,
    AclAxisPointY.center => rect.center.dy,
    AclAxisPointY.bottom => rect.bottom,
  };

  int _ordinalY(AclAxisPointY p) => switch (p) {
    AclAxisPointY.top => 0,
    AclAxisPointY.center => 1,
    AclAxisPointY.bottom => 2,
  };

  int _ordinalX(AclAxisPointX p) => switch (p) {
    AclAxisPointX.left => 0,
    AclAxisPointX.center => 1,
    AclAxisPointX.right => 2,
  };

  /// Direction multiplier for `gap` on Y-axis alignments.
  /// +1 when self lands below ref (e.g. TopToBottom) — positive gap pushes down.
  /// -1 when self lands above ref (e.g. BottomToTop) — positive gap pushes up.
  /// -1 (preserving legacy behaviour) for same-ordinal alignments where no
  ///   obvious "away" direction exists (TopToTop, CenterToCenter, BottomToBottom).
  double _gapSignY(AclAxisPointY self, AclAxisPointY ref) {
    final s = _ordinalY(self);
    final r = _ordinalY(ref);
    if (s < r) return 1.0;
    if (s > r) return -1.0;
    return -1.0;
  }

  /// Direction multiplier for `gap` on X-axis alignments — mirror of _gapSignY.
  double _gapSignX(AclAxisPointX self, AclAxisPointX ref) {
    final s = _ordinalX(self);
    final r = _ordinalX(ref);
    if (s < r) return 1.0;
    if (s > r) return -1.0;
    return -1.0;
  }

  double _horizontalOffset(AclAxisPointX point, double width) =>
      switch (point) {
        AclAxisPointX.left => 0,
        AclAxisPointX.center => width / 2,
        AclAxisPointX.right => width,
      };
}

// ── AclLayout / Acl ──────────────────────────────────────────────────────────

class AclLayout extends StatelessWidget {
  final List<AclRow> rows;
  final AclBorderStyle borderStyle;
  final AclBorderStyle? focusedBorderStyle;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final bool scrollableX;
  final bool scrollableY;
  final Size? preferredContainerSize;
  final Size? minimumContainerSize;
  final Size? maximumContainerSize;
  final String? aclId;
  final bool idScope;
  final String? aclGroup;
  final String? parentIdPath;
  final Map<String, AclGroupVisibilityController> groupVisibilityControllers;
  final List<AclVariant> variants;
  final AclDirection? direction;
  final bool defaultHideUnauthorized;

  const AclLayout({
    super.key,
    required this.rows,
    this.borderStyle = const AclBorderStyle.none(),
    this.focusedBorderStyle,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.scrollableX = false,
    this.scrollableY = false,
    this.preferredContainerSize,
    this.minimumContainerSize,
    this.maximumContainerSize,
    this.aclId,
    this.idScope = false,
    this.aclGroup,
    this.parentIdPath,
    this.groupVisibilityControllers = const {},
    this.variants = const [],
    this.direction,
    this.defaultHideUnauthorized = false,
  });

  @override
  Widget build(BuildContext context) {
    return AclContainer(
      rows: rows,
      borderStyle: borderStyle,
      focusedBorderStyle: focusedBorderStyle,
      padding: padding,
      backgroundColor: backgroundColor,
      scrollableX: scrollableX,
      scrollableY: scrollableY,
      preferredContainerSize: preferredContainerSize,
      minimumContainerSize: minimumContainerSize,
      maximumContainerSize: maximumContainerSize,
      aclId: aclId,
      idScope: idScope,
      aclGroup: aclGroup,
      parentIdPath: parentIdPath,
      groupVisibilityControllers: groupVisibilityControllers,
      variants: variants,
      direction: direction,
      defaultHideUnauthorized: defaultHideUnauthorized,
    );
  }
}

class Acl extends AclLayout {
  final String? title;
  final Widget? titleWidget;
  final TextStyle? titleStyle;
  final AclTitlePosition titlePosition;
  final AclTitleBorderAlign titleBorderAlign;
  final double titleVerticalOffset;

  const Acl({
    super.key,
    required super.rows,
    super.borderStyle = const AclBorderStyle.none(),
    super.focusedBorderStyle,
    super.padding = EdgeInsets.zero,
    super.backgroundColor,
    super.scrollableX = false,
    super.scrollableY = false,
    super.preferredContainerSize,
    super.minimumContainerSize,
    super.maximumContainerSize,
    super.aclId,
    super.idScope = false,
    super.aclGroup,
    super.parentIdPath,
    super.groupVisibilityControllers = const {},
    super.variants = const [],
    super.direction,
    super.defaultHideUnauthorized = false,
    this.title,
    this.titleWidget,
    this.titleStyle,
    this.titlePosition = AclTitlePosition.topLeft,
    this.titleBorderAlign = AclTitleBorderAlign.bottom,
    this.titleVerticalOffset = 0.0,
  });

  /// Vertical space reserved above the border line for the title label.
  /// The AclContainer is pushed down by this amount inside the Stack.
  static const double _kTitleReserve = 14.0;

  /// Extra vertical extent of the background-coloured mask beyond the title
  /// content. This ensures the mask overlaps (and hides) the border line
  /// regardless of alignment. Must be at least as large as the thickest
  /// border (solidDouble ≈ lineWidth*2 + 4).
  static const double _kBorderMask = 4.0;

  /// Approximate font descent used to shift [AclTitleBorderAlign.bottom]
  /// so the text baseline — not the descender line — sits on the border.
  static const double _kBaselineDescentAdjust = 3.0;

  @override
  Widget build(BuildContext context) {
    final hasTitle =
        titleWidget != null || (title != null && title!.isNotEmpty);
    if (!hasTitle) return super.build(context);

    final isRtl =
        (direction ?? AclDirectionScope.maybeOf(context) ?? AclDirection.ltr) ==
        AclDirection.rtl;

    final theme = Theme.of(context);
    final bg = backgroundColor ?? theme.scaffoldBackgroundColor;

    // Build the title label — either a custom widget or styled text.
    // The background-coloured Container extends _kBorderMask above and below
    // the content to fully mask the border segment behind it.
    final Widget titleLabel;
    if (titleWidget != null) {
      titleLabel = Container(
        color: bg,
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: _kBorderMask,
        ),
        child: titleWidget,
      );
    } else {
      final titleTextStyle =
          (titleStyle ??
                  theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ))
              ?.copyWith(height: 1.0);
      titleLabel = Container(
        color: bg,
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: _kBorderMask,
        ),
        child: Text(title!, style: titleTextStyle),
      );
    }

    // FractionalTranslation shifts the label so the desired edge/centre
    // aligns with the anchor Y position.
    final titleTranslation = switch (titleBorderAlign) {
      AclTitleBorderAlign.top => Offset.zero,
      AclTitleBorderAlign.middle => const Offset(0, -0.5),
      AclTitleBorderAlign.bottom => const Offset(0, -1.0),
    };

    // For solidDouble borders the title should centre on the midpoint
    // between the outer and inner border lines rather than the outer edge.
    // Outer centre = w/2, inner centre = 2.5w + 2, midpoint = 1.5w + 1.
    final borderCenterOffset = borderStyle.kind == AclBorderKind.solidDouble
        ? 1.5 * borderStyle.lineWidth + 1.0
        : 0.0;

    // The anchor Y position is shifted per-alignment so the bg-coloured
    // Container always overlaps the full border width:
    //   bottom → anchor pushed _kBorderMask below border top so bg
    //            (whose bottom edge = anchor Y) extends past the border.
    //   middle → anchor at border top; the bg straddles it naturally.
    //   top    → anchor pulled _kBorderMask above border top so bg
    //            (whose top edge = anchor Y) starts before the border.
    final titleY =
        switch (titleBorderAlign) {
          AclTitleBorderAlign.bottom =>
            _kTitleReserve +
                borderCenterOffset +
                _kBorderMask +
                _kBaselineDescentAdjust +
                1.0,
          AclTitleBorderAlign.middle => _kTitleReserve + borderCenterOffset,
          AclTitleBorderAlign.top =>
            _kTitleReserve + borderCenterOffset - _kBorderMask - 5.0,
        } +
        titleVerticalOffset;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: _kTitleReserve),
          child: AclContainer(
            rows: rows,
            borderStyle: _titleAdjustedBorderStyle(
              borderStyle,
              titleBorderAlign,
            ),
            focusedBorderStyle: focusedBorderStyle != null
                ? _titleAdjustedBorderStyle(
                    focusedBorderStyle!,
                    titleBorderAlign,
                  )
                : null,
            padding: padding,
            backgroundColor: backgroundColor,
            scrollableX: scrollableX,
            scrollableY: scrollableY,
            preferredContainerSize: preferredContainerSize,
            minimumContainerSize: minimumContainerSize,
            maximumContainerSize: maximumContainerSize,
            aclId: aclId,
            aclGroup: aclGroup,
            parentIdPath: parentIdPath,
            groupVisibilityControllers: groupVisibilityControllers,
            variants: variants,
            direction: direction,
            defaultHideUnauthorized: defaultHideUnauthorized,
          ),
        ),
        Positioned(
          top: titleY,
          left: _left(isRtl),
          right: _right(isRtl),
          child: Align(
            alignment: _alignment(isRtl),
            child: FractionalTranslation(
              translation: titleTranslation,
              child: titleLabel,
            ),
          ),
        ),
      ],
    );
  }

  /// When no explicit [AclBorderStyle.borderInsets] are set, injects a top
  /// inner inset so content does not overlap the title label where it
  /// protrudes below the border line.
  ///   bottom → label is fully above the border; minimal clearance (4 px)
  ///   middle → half the label hangs below the border (~10 px)
  ///   top    → full label hangs below the border (~18 px)
  AclBorderStyle _titleAdjustedBorderStyle(
    AclBorderStyle style,
    AclTitleBorderAlign align,
  ) {
    if (!style.enabled) return style;
    if (style.borderInsets != EdgeInsets.zero) return style;
    final topInset = switch (align) {
      AclTitleBorderAlign.bottom => 8.0,
      AclTitleBorderAlign.middle => 10.0,
      AclTitleBorderAlign.top => 18.0,
    };
    return style.copyWith(borderInsets: EdgeInsets.fromLTRB(4, topInset, 4, 4));
  }

  /// Effective title position after RTL mirroring: topLeft ↔ topRight.
  AclTitlePosition _effectivePosition(bool isRtl) {
    if (!isRtl) return titlePosition;
    return switch (titlePosition) {
      AclTitlePosition.topLeft => AclTitlePosition.topRight,
      AclTitlePosition.topCenter => AclTitlePosition.topCenter,
      AclTitlePosition.topRight => AclTitlePosition.topLeft,
    };
  }

  Alignment _alignment(bool isRtl) => switch (_effectivePosition(isRtl)) {
    AclTitlePosition.topLeft => Alignment.centerLeft,
    AclTitlePosition.topCenter => Alignment.center,
    AclTitlePosition.topRight => Alignment.centerRight,
  };

  double? _left(bool isRtl) => switch (_effectivePosition(isRtl)) {
    AclTitlePosition.topLeft => 12,
    AclTitlePosition.topCenter => 0,
    AclTitlePosition.topRight => null,
  };

  double? _right(bool isRtl) => switch (_effectivePosition(isRtl)) {
    AclTitlePosition.topLeft => null,
    AclTitlePosition.topCenter => 0,
    AclTitlePosition.topRight => 12,
  };
}

enum AclTitlePosition { topLeft, topCenter, topRight }

/// Controls how the title label is vertically positioned relative to the
/// border line of a titled [Acl] container.
///
/// * [top]    — the top edge of the label sits on the border line; the label
///              hangs downward from the border (into the container interior).
/// * [middle] — the label is centred on the border line; half above, half below.
/// * [bottom] — the bottom edge of the label sits on the border line; the label
///              floats above the border (default, classic field-set look).
enum AclTitleBorderAlign { top, middle, bottom }

// ── Auto-defaulted width: measurement + overflow guard ───────────────────────

/// Wrapper for components whose preferred width was auto-applied by
/// `AclBuilder` rather than declared by the author.
///
/// It does two things the plain `SizedBox(width:)` around every other component
/// cannot:
///
/// * it reports, via [onMinWidth], the narrowest width at which its child can
///   be painted without overflowing, which is what lets the container widen the
///   component to fit its content instead of capping it at the default;
/// * it lays the child out at that width whenever the allocation is smaller,
///   and clips what does not fit — so a container too narrow for the content
///   shows a clean edge rather than the striped overflow banner, and the child
///   keeps the size it laid out at instead of reflowing.
class _AclFloorWidthBox extends SingleChildRenderObjectWidget {
  const _AclFloorWidthBox({required this.onMinWidth, required Widget super.child});

  /// Called during layout with the child's minimum intrinsic width.
  final ValueChanged<double> onMinWidth;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderAclFloorWidthBox(onMinWidth: onMinWidth);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderAclFloorWidthBox renderObject,
  ) {
    renderObject.onMinWidth = onMinWidth;
  }
}

class _RenderAclFloorWidthBox extends RenderProxyBox {
  _RenderAclFloorWidthBox({required this.onMinWidth});

  ValueChanged<double> onMinWidth;

  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle<ClipRectLayer>();

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }

    final minWidth = _minIntrinsicWidthOf(child);
    // The width this component was allocated by the ACL arithmetic. Unbounded
    // only happens outside a sizing wrapper, where the content's own width is
    // the honest answer.
    final allocated =
        constraints.hasBoundedWidth ? constraints.maxWidth : minWidth;
    // Why max(): giving the child less than its minimum is precisely what
    // produces a RenderFlex overflow. Give it the minimum and clip in paint
    // instead — the overflow becomes invisible *and* harmless, and the child's
    // own layout is untouched by how narrow the container happens to be.
    final childWidth = math.max(allocated, minWidth);
    child.layout(
      BoxConstraints(
        minWidth: childWidth,
        maxWidth: childWidth,
        minHeight: constraints.minHeight,
        maxHeight: constraints.maxHeight,
      ),
      parentUsesSize: true,
    );
    size = constraints.constrain(Size(allocated, child.size.height));

    onMinWidth(minWidth);
  }

  /// The narrowest width at which [child] can be painted without overflowing.
  ///
  /// Not every subtree answers the intrinsics protocol — `LayoutBuilder` and
  /// the scrolling viewports throw rather than guess. `debugCheckingIntrinsics`
  /// is the framework's own "an intrinsic query is in flight, degrade instead
  /// of throwing" switch, and degrading is the right outcome here: a child that
  /// cannot report a minimum keeps the plain default width, which is exactly
  /// the behaviour that existed before this box.
  double _minIntrinsicWidthOf(RenderBox child) {
    bool restore = false;
    assert(() {
      restore = !RenderObject.debugCheckingIntrinsics;
      RenderObject.debugCheckingIntrinsics = true;
      return true;
    }());
    double measured;
    try {
      measured = child.getMinIntrinsicWidth(double.infinity);
    } finally {
      assert(() {
        if (restore) RenderObject.debugCheckingIntrinsics = false;
        return true;
      }());
    }
    return measured.isFinite && measured > 0 ? measured : 0;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    if (child.size.width <= size.width + _clipEpsilon) {
      _clipLayer.layer = null;
      context.paintChild(child, offset);
      return;
    }
    _clipLayer.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      (innerContext, innerOffset) => innerContext.paintChild(child, innerOffset),
      oldLayer: _clipLayer.layer,
    );
  }

  /// Sub-pixel slack: a child a rounding error wider than its allocation is not
  /// worth a clip layer.
  static const double _clipEpsilon = 0.01;

  @override
  void dispose() {
    _clipLayer.layer = null;
    super.dispose();
  }
}
