import 'dart:math' as math;

import 'package:flutter/material.dart';

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

  /// Relative weight used when this is a gap slot (isGap == true).
  final double gapWeight;

  final Size? preferredSize;
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

  /// Optional identifier for this component (see §24).
  final String? id;

  /// Optional group name this component belongs to (see §25).
  final String? group;

  /// Whether this component is inside an inline variant block (see §29).
  final bool inlineVariant;

  /// Detector function that determines whether this variant is active (see §29).
  /// Null for the default variant (shown when no other detector matches).
  final AclVariantDetector? variantDetector;

  const AclComponent({
    required this.child,
    this.flags = 0,
    this.gapBefore = 0,
    this.gapWeight = 1.0,
    this.preferredSize,
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
    this.rowCrossAlignment = AclRowCrossAlignment.center,
    this.componentKey,
    this.id,
    this.group,
    this.inlineVariant = false,
    this.variantDetector,
  });

  bool get expandX => (flags & AclFlags.expandX) != 0;
  bool get expandY => (flags & AclFlags.expandY) != 0;
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

  /// Optional identifier for this row (see §24).
  final String? id;

  /// Optional group name this row belongs to (see §25).
  final String? group;

  /// Row breakpoints for responsive splitting (see §28).
  final List<AclRowBreakpoint> breakpoints;

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
    this.breakpoints = const [],
  });
}

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

  _AclRowLayout({
    required this.fittedWidths,
    required this.horizontalDeltas,
    required this.verticalDeltas,
    required this.linkedWidths,
    required this.linkedHeights,
    required this.gapSlotWidths,
    required this.virtualRects,
    required this.estimatedHeight,
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

  /// Optional identifier for this container (see §24).
  final String? aclId;

  /// Optional group name for the entire container (see §25).
  final String? aclGroup;

  /// Parent container ID for building the full ID path (see §24).
  final String? parentIdPath;

  /// Group visibility controllers keyed by group name (see §26).
  final Map<String, AclGroupVisibilityController> groupVisibilityControllers;

  /// Responsive variants sorted by atWidth descending (see §27).
  final List<AclVariant> variants;

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
    this.aclGroup,
    this.parentIdPath,
    this.groupVisibilityControllers = const {},
    this.variants = const [],
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
    if (!identical(oldWidget.groupVisibilityControllers, widget.groupVisibilityControllers)) {
      _unsubscribeVisibilityControllers(oldWidget.groupVisibilityControllers);
      _subscribeVisibilityControllers();
    }
    // AclBuilder generates new GlobalKeys on every build() call. Transfer
    // cached natural sizes from old keys to new keys by structural position
    // (row index × component index) so there is no one-frame cache-miss lag
    // after a parent rebuild.
    _remapNaturalSizeCacheByPosition(oldWidget.rows, widget.rows);
  }

  void _subscribeVisibilityControllers([Map<String, AclGroupVisibilityController>? controllers]) {
    for (final ctrl in (controllers ?? widget.groupVisibilityControllers).values) {
      ctrl.modeNotifier.addListener(_onVisibilityChanged);
    }
  }

  void _unsubscribeVisibilityControllers([Map<String, AclGroupVisibilityController>? controllers]) {
    for (final ctrl in (controllers ?? widget.groupVisibilityControllers).values) {
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
      }
    }
    _naturalSizeCache
      ..clear()
      ..addAll(newCache);
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
      final active = row.breakpoints
          .where((bp) => availableWidth < bp.atWidth)
          .toList()
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
        final dist = i == 0 ? row.gapBefore : active.firstWhere((b) => b.splitAfter == end, orElse: () => active.first).splitRowDist;
        result.add(AclRow(
          components: row.components.sublist(start, end),
          alignment: row.alignment,
          gapBefore: i == 0 ? row.gapBefore : dist,
          id: i == 0 ? row.id : null,
          group: row.group,
          breakpoints: const [],
        ));
        start = end;
      }
      if (start < row.components.length) {
        result.add(AclRow(
          components: row.components.sublist(start),
          alignment: row.alignment,
          gapBefore: active.last.splitRowDist,
          group: row.group,
          breakpoints: const [],
        ));
      }
    }
    return result;
  }

  /// Filters components within each row based on inline variant detectors
  /// (§29). Components not in any variant block are always kept. Components
  /// in a variant block are kept only when their detector is the active one.
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
      result.add(AclRow(
        components: filtered,
        alignment: row.alignment,
        gapBefore: row.gapBefore,
        isGapRow: row.isGapRow,
        gapRowWeight: row.gapRowWeight,
        separator: row.separator,
        gapRowMinSize: row.gapRowMinSize,
        id: row.id,
        group: row.group,
        breakpoints: row.breakpoints,
      ));
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

  /// Wraps a component with [AclScope] to provide ID/group metadata.
  Widget _wrapWithScope(Widget child, AclComponent comp, AclRow row) {
    final containerId = widget.aclId;
    final parentPath = widget.parentIdPath;
    String? fullPath;
    if (comp.id != null) {
      final parts = <String>[
        ?parentPath,
        ?containerId,
        if (row.id != null) row.id!,
        comp.id!,
      ];
      fullPath = parts.join('.');
    }
    return AclScope(
      containerId: containerId,
      componentId: comp.id,
      rowId: row.id,
      groupName: comp.group ?? row.group,
      fullIdPath: fullPath,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content = _buildContent(context);

    // Container-level height/width constraints. minContW is handled inside
    // _buildContent (inside LayoutBuilder) so expandX/gap use the correct width.
    final minContH = widget.minimumContainerSize?.height ??
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

    content = _wrapWithBorder(content, activeBorderStyle);

    if (widget.padding != EdgeInsets.zero) {
      content = Padding(padding: widget.padding, child: content);
    }

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

    for (int i = 0; i < row.components.length; i++) {
      final comp = row.components[i];
      if (skip(comp)) continue;

      final linkedW = linkedWidths[i] ??
          (comp.useOtherDimX ? crossRowVirtualRects[comp.referenceKey]?.width : null);

      final bool collapseToVisual = comp.alignXToKey == null && maxHX < plannedX;
      if (comp.gapBefore > 0 && !collapseToVisual) plannedX += comp.gapBefore;

      final delta = collapseToVisual
          ? (maxHX + comp.gapBefore - plannedX)
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

      final h =
          (comp.preferredSize?.height ?? comp.minimumSize?.height ?? 0)
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

    if (naturalWidth <= availableWidth) {
      // ── Grow phase ─────────────────────────────────────────────────────
      // Natural-sized (no-hint) components use cached size as seed.
      final hasRowFiller =
          row.components.any((c) => (c.expandX && !c.isGap) || c.isGap);
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
          naturalExcludedWidth += _naturalWidth(comp) ??
              (comp.child is SizedBox
                  ? ((comp.child as SizedBox).width ?? 0.0)
                  : 0.0);
        }

        final effectiveSurplus = math.max(
          0.0,
          availableWidth - naturalWidth - naturalExcludedWidth,
        );
        if (effectiveSurplus >= 1) {
          double totalPref = 0;
          for (int i = 0; i < row.components.length; i++) {
            final comp = row.components[i];
            if (skip(comp)) continue;
            if (comp.useOtherDimX) continue;
            if (comp.preferredSize == null &&
                comp.minimumSize == null &&
                comp.maximumSize == null) {
              continue;
            }
            totalPref += prefWidths[i] ?? 0.0;
          }
          if (totalPref >= 1) {
            final grown = <int, double>{};
            for (int i = 0; i < row.components.length; i++) {
              final comp = row.components[i];
              if (skip(comp)) continue;
              if (comp.useOtherDimX) continue;
              if (comp.preferredSize == null &&
                  comp.minimumSize == null &&
                  comp.maximumSize == null) {
                continue;
              }
              final pref = prefWidths[i] ?? 0.0;
              final share = effectiveSurplus * pref / totalPref;
              final max = comp.maximumSize?.width;
              grown[i] = (max != null && max.isFinite)
                  ? math.min(pref + share, max)
                  : pref + share;
            }
            if (grown.isNotEmpty) return grown;
          }
        }
      }
      return null;
    }

    // ── Shrink phase ────────────────────────────────────────────────────────
    final deficit = naturalWidth - availableWidth;
    double shrinkCap = 0;
    for (int i = 0; i < row.components.length; i++) {
      final comp = row.components[i];
      if (skip(comp)) continue;
      if (comp.useOtherDimX) continue;
      shrinkCap += math.max(
        0.0,
        (prefWidths[i] ?? 0) -
            (comp.minimumSize?.width ?? comp.preferredSize?.width ?? 0),
      );
    }
    if (shrinkCap < 1) return null;

    final ratio = (deficit / shrinkCap).clamp(0.0, 1.0);
    final fitted = <int, double>{};
    for (int i = 0; i < row.components.length; i++) {
      final comp = row.components[i];
      if (skip(comp)) continue;
      if (comp.useOtherDimX) continue;
      if (comp.preferredSize == null && comp.minimumSize == null) continue;
      final pref = prefWidths[i] ?? 0.0;
      final min = comp.minimumSize?.width ?? comp.preferredSize?.width ?? 0.0;
      fitted[i] = pref - math.max(0.0, pref - min) * ratio;
    }
    return fitted;
  }

  // ── Border rendering ───────────────────────────────────────────────────────

  Widget _wrapWithBorder(Widget content, AclBorderStyle style) {
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
        // no explicit borderInsets were configured.
        : style.enabled
            ? Padding(padding: const EdgeInsets.all(4), child: content)
            : content;

    if (style.kind == AclBorderKind.solidDouble) {
      final innerRadius =
          radius > 0 ? (radius - 2.0).clamp(0.0, radius) : 0.0;
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
      AclBorderKind.top =>
        Border(top: BorderSide(color: color, width: style.lineWidth)),
      AclBorderKind.bottom =>
        Border(bottom: BorderSide(color: color, width: style.lineWidth)),
      AclBorderKind.left =>
        Border(left: BorderSide(color: color, width: style.lineWidth)),
      AclBorderKind.right =>
        Border(right: BorderSide(color: color, width: style.lineWidth)),
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

  // ── Content building ───────────────────────────────────────────────────────

  Widget _buildContent(BuildContext context) {
    final minContW = (widget.minimumContainerSize?.width ??
            widget.preferredContainerSize?.width ??
            0.0)
        .clamp(0.0, double.maxFinite);

    return LayoutBuilder(
      builder: (context, constraints) {
        final rawMaxW =
            constraints.hasBoundedWidth ? constraints.maxWidth : 0.0;
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
          variantRows, deviceCtx, parentAcl, context,
        );
        final effectiveRows = _applyRowBreakpoints(
          inlineFilteredRows,
          canExpandHorizontally ? effectiveMaxW : null,
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

        // ── Assemble Flutter widget tree from pre-computed values ────────
        final List<Widget> rowWidgets = [];
        int contentRowIndex = 0;

        for (final row in effectiveRows) {
          if (row.isGapRow) {
            if (!widget.scrollableY && canExpandVertically) {
              if (!hasExpandY) {
                // No expandY rows in layout: gap rows expand proportionally.
                final weight =
                    (row.gapRowWeight * 1000).round().clamp(1, 1000000);
                final gapContent = row.separator != null
                    ? _buildSeparatorWidget(row.separator!)
                    : const SizedBox.expand();
                rowWidgets.add(
                  Flexible(
                    flex: weight,
                    fit: FlexFit.tight,
                    child: gapContent,
                  ),
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
            }
            continue;
          }

          if (row.gapBefore > 0) {
            rowWidgets.add(SizedBox(height: row.gapBefore));
          }

          final layout = rowLayouts[contentRowIndex++];
          rowWidgets.add(
            _buildRow(
              row: row,
              layout: layout,
              canExpandHorizontally: canExpandHorizontally,
              canExpandVertically: canExpandVertically,
              availableWidth: canExpandHorizontally ? effectiveMaxW : null,
            ),
          );
        }

        Widget column = Column(
          mainAxisSize: useMaxVertical ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: canExpandHorizontally
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.start,
          children: rowWidgets,
        );

        if (!canExpandHorizontally) {
          column = UnconstrainedBox(alignment: Alignment.topLeft, child: column);
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
    final contentRows =
        rows.where((r) => !r.isGapRow).toList(growable: false);

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
        totalFitted += fittedWidths[i] ??
            linkedWidths[i] ??
            comp.preferredSize?.width ??
            _naturalWidth(comp) ??
            0;
      }
      final gapRemaining =
          math.max(0.0, availableWidth - totalFitted);
      final gapWeightSum = row.components
          .where((c) => c.isGap)
          .fold(0.0, (s, c) => s + c.gapWeight);
      if (gapWeightSum > 0 && !widget.scrollableX) {
        for (int i = 0; i < row.components.length; i++) {
          final comp = row.components[i];
          if (!comp.isGap) continue;
          gapSlotWidths[i] =
              (gapRemaining * comp.gapWeight / gapWeightSum)
                  .clamp(0.0, double.infinity);
        }
      }
    }

    // ── Build virtual rects and compute alignment deltas ──────────────────
    double plannedX = 0;
    double maxHorizontalX = 0;
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

      final isFlexNative = comp.child is Flexible ||
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
      if (comp.gapBefore > 0) {
        plannedX += comp.gapBefore;
      }

      final linkedW = linkedWidths[i];
      final linkedH = linkedHeights[i];

      // Horizontal alignment delta
      if (!isFlexNative && !hasExplicitXAlignment && maxHorizontalX < priorPlannedX) {
        // collapseToVisual: maxHX lags behind the natural planned position.
        // Place component at maxHX + gapBefore by using priorPlannedX as base.
        hDelta = maxHorizontalX - priorPlannedX;
      } else if (hasExplicitXAlignment) {
        // For components with explicit X alignment in rows that do not fill
        // the available width, _buildRow wraps every child with
        // ConstrainedBox(maxWidth: constraints.maxWidth). The actual rendered
        // width is therefore min(preferredWidth, containerWidth). Feed the same
        // effective width into _calcHorizontalDelta so the centre point is right.
        final rowFillsWidth =
            row.components.any((c) => (c.expandX && !c.isGap) || c.isGap);
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

      final estimatedW = _estimateW(comp, linkedW, fittedWidths[i]);
      final estimatedH = _estimateH(comp, linkedH);

      rowEstimatedHeight = math.max(rowEstimatedHeight, estimatedH);

      final shiftedLeft = plannedX + (hDelta < 0 ? hDelta : 0);
      final shiftedRight = shiftedLeft + estimatedW;
      maxHorizontalX = math.max(maxHorizontalX, shiftedRight);

      final key = comp.componentKey;
      if (key != null) {
        final vRect =
            Rect.fromLTWH(shiftedLeft, 0, estimatedW, estimatedH);
        virtualRects[key] = vRect;
        sameRowVirtualRects[key] = vRect;
      }

      plannedX += (hDelta > 0 ? hDelta : 0) + estimatedW;
    }

    // ── Vertical alignment deltas (same-row) ─────────────────────────────
    // Requires virtual rects to be built first; update them with Y offsets.
    //
    // Virtual rects all have top=0. But _buildRow places each component at
    // baseTopInRow = (rowH - compH) / 2 by default (centred in the row).
    // We must adjust the rect Y by this default offset so the delta reflects
    // a shift FROM that default position, not from an artificial top=0.
    final hasRowExpandY = row.components.any((c) => !c.isGap && c.expandY);
    for (int i = 0; i < row.components.length; i++) {
      final comp = row.components[i];
      if (comp.alignYToKey == null ||
          comp.alignYFrom == null ||
          comp.alignYTo == null ||
          comp.componentKey == null) {
        continue;
      }

      final selfRect = virtualRects[comp.componentKey];
      final refRect = sameRowVirtualRects[comp.alignYToKey] ??
          virtualRects[comp.alignYToKey];
      if (selfRect == null || refRect == null) continue;

      // When the row has expandY components, baseTopInRow = 0; otherwise
      // each component defaults to (rowH - compH) / 2 (centred).
      double defaultTop(Rect r) => hasRowExpandY
          ? 0.0
          : (rowEstimatedHeight - r.height) / 2;

      final adjSelfRect = selfRect.translate(0, defaultTop(selfRect));
      final adjRefRect  = refRect.translate(0, defaultTop(refRect));

      final selfPoint = _verticalPoint(adjSelfRect, comp.alignYFrom!);
      final refPoint  = _verticalPoint(adjRefRect,  comp.alignYTo!);
      final delta = (refPoint - comp.alignYGap) - selfPoint;
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
    );
  }

  // ── Natural size helpers ──────────────────────────────────────────────────

  double? _naturalWidth(AclComponent comp) {
    final key = comp.componentKey;
    if (key == null) return null;
    return _naturalSizeCache[key]?.width ??
        (comp.child is SizedBox
            ? (comp.child as SizedBox).width
            : null);
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
    if (linkedHeight != null) return linkedHeight.clamp(0, double.infinity);
    return (comp.preferredSize?.height ??
            comp.minimumSize?.height ??
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
    final refRect =
        crossRowVirtualRects[key] ?? virtualRects[key];
    if (refRect == null) return 0;

    final widthEstimate = linkedWidth ??
        (comp.preferredSize?.width ??
            comp.minimumSize?.width ??
            _naturalWidth(comp) ??
            0);
    final selfPoint =
        plannedX + _horizontalOffset(comp.alignXFrom!, widthEstimate);
    final targetPoint = _horizontalPoint(refRect, comp.alignXTo!);
    return (targetPoint - comp.alignXGap) - selfPoint;
  }

  Widget _buildSeparatorWidget(AclSeparator separator) {
    return LayoutBuilder(builder: (context, _) {
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
    });
  }

  // ── Row widget assembly (Flutter tree only — all values pre-computed) ───────

  Widget _buildRow({
    required AclRow row,
    required _AclRowLayout layout,
    required bool canExpandHorizontally,
    required bool canExpandVertically,
    double? availableWidth,
  }) {
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
        ? row.components.where((c) => c.isGap).fold(0.0, (s, c) => s + c.gapWeight)
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
                ? row.components.where((c) => c.expandX && !c.isGap).fold(0.0, (s, c) {
                    final pref = c.preferredSize?.width ?? 0.0;
                    final min = c.minimumSize?.width ?? 0.0;
                    final diff = pref - min;
                    return s + (diff > 0 && diff.isFinite ? diff : 1000.0);
                  })
                : 0.0;
            final int flex;
            if (totalExpandXFlex > 0) {
              flex =
                  ((component.gapWeight / gapWeightSum) * totalExpandXFlex).round().clamp(1, 100000);
            } else {
              flex = (component.gapWeight / gapWeightSum * 10000).round().clamp(1, 10000);
            }
            children.add(Spacer(flex: flex));
          } else {
            final gapWidth =
                (layout.gapSlotWidths[componentIndex] ?? 0).clamp(0.0, double.infinity);
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
      final verticalAlignmentOffset = layout.verticalDeltas[componentIndex] ?? 0.0;

      // Always emit gapBefore — the pre-calc always accounts for it in plannedX
      // so the alignmentDelta is always measured from after the gap.
      if (component.gapBefore > 0) {
        children.add(SizedBox(width: component.gapBefore));
        plannedX += component.gapBefore;
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

      // Wrap with AclScope to provide ID/group metadata.
      child = _wrapWithScope(child, component, row);
      // Apply disabled treatment if needed.
      if (visMode == AclGroupVisibilityMode.disabled) {
        child = IgnorePointer(
          child: Opacity(opacity: 0.4, child: child),
        );
      }

      final linkedWidth = layout.linkedWidths[componentIndex];
      final linkedHeight = layout.linkedHeights[componentIndex];
      final fittedWidth = layout.fittedWidths[componentIndex];

      final minWidth = component.useOtherDimX
          ? (linkedWidth ?? component.minimumSize?.width ?? component.preferredSize?.width)
          : (component.minimumSize?.width ?? component.preferredSize?.width);
      final minHeight = component.useOtherDimY
          ? (linkedHeight ?? component.minimumSize?.height ?? component.preferredSize?.height)
          : (component.minimumSize?.height ?? component.preferredSize?.height);
      // For useOtherDimX components whose reference is not yet resolved (first frame),
      // fall back to availableWidth as maxWidth — prevents TextField/Dropdown
      // "unbounded width" assertion inside Row(mainAxisSize.max) rows.
      final maxWidth = component.useOtherDimX
          ? (linkedWidth ??
              component.maximumSize?.width ??
              (availableWidth?.isFinite == true ? availableWidth : null))
          : component.maximumSize?.width;
      final maxHeight = component.useOtherDimY
          ? (linkedHeight ?? component.maximumSize?.height)
          : component.maximumSize?.height;

      if (!isFlexNativeChild &&
          (minWidth != null || minHeight != null || maxWidth != null || maxHeight != null)) {
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

      if (!isFlexNativeChild && (!component.expandX || !canExpandHorizontally)) {
        final effectiveWidth = fittedWidth ?? component.preferredSize?.width;
        if (effectiveWidth != null) {
          child = SizedBox(width: effectiveWidth, child: child);
        }
      }

      if (!isFlexNativeChild && (!component.expandY || !canExpandVertically)) {
        final preferredHeight = component.preferredSize?.height;
        if (preferredHeight != null) {
          child = SizedBox(height: preferredHeight, child: child);
        }
      }

      final hasFiniteMaxWidth = (component.maximumSize?.width ?? double.infinity).isFinite;
      if (!isFlexNativeChild && component.expandX && canExpandHorizontally && !hasFiniteMaxWidth) {
        child = SizedBox(width: double.infinity, child: child);
      }

      final estimatedWidth = _estimateW(component, linkedWidth, fittedWidth);
      final estimatedHeight = _estimateH(component, linkedHeight);

      final shiftedLeftInRow = plannedX + (alignmentDelta < 0 ? alignmentDelta : 0);
      final shiftedRightInRow = shiftedLeftInRow + estimatedWidth;
      minHorizontalX = math.min(minHorizontalX, shiftedLeftInRow);
      maxHorizontalX = math.max(maxHorizontalX, shiftedRightInRow);
      rowEstimatedWidth = math.max(rowEstimatedWidth, plannedX + estimatedWidth);

      if (!isFlexNativeChild && component.componentKey != null) {
        if (component.expandY && canExpandVertically) {
          // expandY: use a transparent SizedBox to carry the key without
          // loosening the cross-axis (height) constraints that allow this
          // component to fill the row.
          child = SizedBox(key: component.componentKey, child: child);
        } else {
          child = Align(
            key: component.componentKey,
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            heightFactor: 1,
            child: child,
          );
        }
      }

      // Skip cross-alignment wrapping for expandY components — they are
      // stretched by CrossAxisAlignment.stretch and must not have their
      // height constraints loosened by an Align(heightFactor:1) wrapper.
      if (!isFlexNativeChild && !(component.expandY && canExpandVertically)) {
        child = _wrapWithRowCrossAlignment(child, component.rowCrossAlignment);
      }

      if (!isFlexNativeChild && alignmentDelta < 0) {
        child = Transform.translate(offset: Offset(alignmentDelta, 0), child: child);
      }

      final baseTopInRow = hasExpandY && canExpandVertically
          ? 0.0
          : (rowEstimatedHeight - estimatedHeight) / 2;
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

      if (component.expandX && canExpandHorizontally) {
        final hasOwnFlexParentData = child is Flexible || child is Spacer;
        if (!hasOwnFlexParentData) {
          final minW =
              (component.minimumSize?.width ?? linkedWidth ?? 0).clamp(0.0, double.maxFinite);
          final prefW =
              (fittedWidth ?? component.preferredSize?.width ?? minW).clamp(minW, double.maxFinite);
          final diff = prefW - minW;
          final flexWeight = (diff.isFinite ? diff.round() : 1000).clamp(1, 10000);
          child = Flexible(flex: flexWeight, fit: FlexFit.tight, child: child);
        }
      }

      children.add(child);
      plannedX += estimatedWidth;
    }

    // ── Row widget assembly ───────────────────────────────────────────────────

    Widget rowWidget;
    final double extraLeft = minHorizontalX < 0 ? -minHorizontalX : 0.0;

    if (!rowFillsWidth && canExpandHorizontally) {
      rowWidget = LayoutBuilder(
        builder: (context, constraints) {
          final boundedChildren = children
              .map(
                (child) => child is Flexible || child is Spacer
                    ? child
                    : ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                        child: child,
                      ),
              )
              .toList();

          final rowContent = Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: hasExpandY && canExpandVertically
                ? CrossAxisAlignment.stretch
                : CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: boundedChildren,
          );

          final alignment = switch (mainAxisAlignment) {
            MainAxisAlignment.end ||
            MainAxisAlignment.spaceBetween ||
            MainAxisAlignment.spaceAround ||
            MainAxisAlignment.spaceEvenly =>
              Alignment.centerRight,
            MainAxisAlignment.center => Alignment.center,
            _ => Alignment.centerLeft,
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
        mainAxisAlignment: hasGapSlots ? MainAxisAlignment.start : mainAxisAlignment,
        crossAxisAlignment: hasExpandY && canExpandVertically
            ? CrossAxisAlignment.stretch
            : CrossAxisAlignment.center,
        mainAxisSize:
            rowFillsWidth && canExpandHorizontally ? MainAxisSize.max : MainAxisSize.min,
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

    if (hasExpandY && canExpandVertically) {
      int rowFlex = 1;
      for (final component in row.components) {
        if (!component.expandY) continue;
        final linkedH = layout.linkedHeights[row.components.indexOf(component)];
        final minH = (component.minimumSize?.height ?? linkedH ?? 0).clamp(0, double.infinity);
        final prefH = (component.preferredSize?.height ?? minH).clamp(minH, double.infinity);
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
    return Align(alignment: alignment, widthFactor: 1, heightFactor: 1, child: child);
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

  double _horizontalOffset(AclAxisPointX point, double width) => switch (point) {
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
  final String? aclGroup;
  final String? parentIdPath;
  final Map<String, AclGroupVisibilityController> groupVisibilityControllers;
  final List<AclVariant> variants;

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
    this.aclGroup,
    this.parentIdPath,
    this.groupVisibilityControllers = const {},
    this.variants = const [],
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
      aclGroup: aclGroup,
      parentIdPath: parentIdPath,
      groupVisibilityControllers: groupVisibilityControllers,
      variants: variants,
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
    super.aclGroup,
    super.parentIdPath,
    super.groupVisibilityControllers = const {},
    super.variants = const [],
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
    final hasTitle = titleWidget != null ||
        (title != null && title!.isNotEmpty);
    if (!hasTitle) return super.build(context);

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
      final titleTextStyle = (titleStyle ??
          theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))
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
    final borderCenterOffset =
        borderStyle.kind == AclBorderKind.solidDouble
            ? 1.5 * borderStyle.lineWidth + 1.0
            : 0.0;

    // The anchor Y position is shifted per-alignment so the bg-coloured
    // Container always overlaps the full border width:
    //   bottom → anchor pushed _kBorderMask below border top so bg
    //            (whose bottom edge = anchor Y) extends past the border.
    //   middle → anchor at border top; the bg straddles it naturally.
    //   top    → anchor pulled _kBorderMask above border top so bg
    //            (whose top edge = anchor Y) starts before the border.
    final titleY = switch (titleBorderAlign) {
      AclTitleBorderAlign.bottom =>
        _kTitleReserve + borderCenterOffset + _kBorderMask + _kBaselineDescentAdjust + 1.0,
      AclTitleBorderAlign.middle => _kTitleReserve + borderCenterOffset,
      AclTitleBorderAlign.top => _kTitleReserve + borderCenterOffset - _kBorderMask - 5.0,
    } + titleVerticalOffset;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: _kTitleReserve),
          child: AclContainer(
            rows: rows,
            borderStyle: _titleAdjustedBorderStyle(borderStyle, titleBorderAlign),
            focusedBorderStyle: focusedBorderStyle != null
                ? _titleAdjustedBorderStyle(focusedBorderStyle!, titleBorderAlign)
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
          ),
        ),
        Positioned(
          top: titleY,
          left: _left(),
          right: _right(),
          child: Align(
            alignment: _alignment(),
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
    return style.copyWith(
      borderInsets: EdgeInsets.fromLTRB(4, topInset, 4, 4),
    );
  }

  Alignment _alignment() => switch (titlePosition) {
        AclTitlePosition.topLeft => Alignment.centerLeft,
        AclTitlePosition.topCenter => Alignment.center,
        AclTitlePosition.topRight => Alignment.centerRight,
      };

  double? _left() => switch (titlePosition) {
        AclTitlePosition.topLeft => 12,
        AclTitlePosition.topCenter => 0,
        AclTitlePosition.topRight => null,
      };

  double? _right() => switch (titlePosition) {
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
