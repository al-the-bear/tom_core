import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'acl_flags.dart';
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

  const AclRow({
    required this.components,
    this.alignment = RowAlignment.left,
    this.gapBefore = 0,
    this.isGapRow = false,
    this.gapRowWeight = 1.0,
    this.separator,
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
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AclContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // AclBuilder generates new GlobalKeys on every build() call. Transfer
    // cached natural sizes from old keys to new keys by structural position
    // (row index × component index) so there is no one-frame cache-miss lag
    // after a parent rebuild.
    _remapNaturalSizeCacheByPosition(oldWidget.rows, widget.rows);
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
    final hasExpandY = widget.rows.any(
      (row) => !row.isGapRow && row.components.any((c) => c.expandY),
    );
    final hasGapRows =
        widget.rows.any((row) => row.isGapRow) && !widget.scrollableY;
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
        final useMaxVertical =
            (hasExpandY || hasGapRows) && canExpandVertically;
        final needsHorizontalScroll =
            !widget.scrollableX &&
            minContW > 0 &&
            constraints.hasBoundedWidth &&
            rawMaxW < minContW;

        // ── Pre-calculation loop ─────────────────────────────────────────
        // Run iterations in pure Dart until all sizes and alignment deltas
        // converge. The render tree is only consulted once via the
        // _naturalSizeCache (populated by the post-frame callback).
        final rowLayouts = _runPreCalcLoop(
          effectiveMaxW: canExpandHorizontally ? effectiveMaxW : null,
        );

        // ── Assemble Flutter widget tree from pre-computed values ────────
        final List<Widget> rowWidgets = [];
        int contentRowIndex = 0;

        for (final row in widget.rows) {
          if (row.isGapRow) {
            if (!widget.scrollableY && canExpandVertically) {
              final weight =
                  (row.gapRowWeight * 1000).round().clamp(1, 1000000);
              final gapContent = row.separator != null
                  ? _buildSeparatorWidget(row.separator!)
                  : const SizedBox.expand();
              rowWidgets.add(
                Flexible(flex: weight, fit: FlexFit.tight, child: gapContent),
              );
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
  List<_AclRowLayout> _runPreCalcLoop({required double? effectiveMaxW}) {
    final contentRows =
        widget.rows.where((r) => !r.isGapRow).toList(growable: false);

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
      final collapseToVisual =
          !isFlexNative && !hasExplicitXAlignment && maxHorizontalX < plannedX;

      if (comp.gapBefore > 0 && !collapseToVisual) {
        plannedX += comp.gapBefore;
      }

      final linkedW = linkedWidths[i];
      final linkedH = linkedHeights[i];

      // Horizontal alignment delta
      double hDelta = 0;
      if (collapseToVisual) {
        hDelta = maxHorizontalX + comp.gapBefore - plannedX;
      } else if (hasExplicitXAlignment) {
        hDelta = _calcHorizontalDelta(
          comp: comp,
          plannedX: plannedX,
          linkedWidth: linkedW,
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

      final selfPoint = _verticalPoint(selfRect, comp.alignYFrom!);
      final refPoint = _verticalPoint(refRect, comp.alignYTo!);
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

      final bool collapseToVisual =
          !isFlexNativeChild &&
          component.alignXToKey == null &&
          maxHorizontalX < plannedX;

      // gapBefore is already baked into the plannedX tracking in _computeRowLayout.
      // We still need to emit the SizedBox(gapBefore) for the Flutter row unless
      // collapseToVisual suppresses it (in which case the alignmentDelta handles it).
      if (component.gapBefore > 0 && !collapseToVisual) {
        children.add(SizedBox(width: component.gapBefore));
        plannedX += component.gapBefore;
      }

      if (alignmentDelta > 0) {
        children.add(SizedBox(width: alignmentDelta));
        plannedX += alignmentDelta;
      }

      Widget child = component.child;

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
        child = Align(
          key: component.componentKey,
          alignment: Alignment.centerLeft,
          widthFactor: 1,
          heightFactor: 1,
          child: child,
        );
      }

      if (!isFlexNativeChild) {
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
    );
  }
}

class Acl extends AclLayout {
  final String? title;
  final TextStyle? titleStyle;
  final AclTitlePosition titlePosition;

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
    this.title,
    this.titleStyle,
    this.titlePosition = AclTitlePosition.topLeft,
  });

  @override
  Widget build(BuildContext context) {
    if (title == null || title!.isEmpty) return super.build(context);

    final theme = Theme.of(context);
    final titleTextStyle = titleStyle ??
        theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);
    final bg = backgroundColor ?? theme.scaffoldBackgroundColor;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AclContainer(
          rows: rows,
          borderStyle: _titleAdjustedBorderStyle(borderStyle),
          focusedBorderStyle: focusedBorderStyle != null
              ? _titleAdjustedBorderStyle(focusedBorderStyle!)
              : null,
          padding: padding.add(const EdgeInsets.only(top: 14)),
          backgroundColor: backgroundColor,
          scrollableX: scrollableX,
          scrollableY: scrollableY,
          preferredContainerSize: preferredContainerSize,
          minimumContainerSize: minimumContainerSize,
          maximumContainerSize: maximumContainerSize,
        ),
        Positioned(
          top: 0,
          left: _left(),
          right: _right(),
          child: Align(
            alignment: _alignment(),
            child: Container(
              color: bg,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(title!, style: titleTextStyle),
            ),
          ),
        ),
      ],
    );
  }

  /// When no explicit [AclBorderStyle.borderInsets] are set, injects an extra
  /// top inner inset so that content starts below the floating title text.
  AclBorderStyle _titleAdjustedBorderStyle(AclBorderStyle style) {
    if (!style.enabled) return style;
    if (style.borderInsets != EdgeInsets.zero) return style;
    return style.copyWith(
      borderInsets: const EdgeInsets.fromLTRB(4, 10, 4, 4),
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
