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
  final FocusNode _focusNode = FocusNode();
  bool _hasFocusWithin = false;
  bool _hasUnresolvedReference = false;
  bool _referenceRelayoutScheduled = false;
  bool _referenceCacheRefreshScheduled = false;
  final Map<Key, Size> _referenceSizeCache = {};
  final Map<Key, Rect> _referenceRectCache = {};
  final Map<Key, double> _appliedHorizontalOffsetByKey = {};
  final Map<Key, double> _appliedVerticalOffsetByKey = {};

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _hasUnresolvedReference = false;

    Widget content = _buildContent(context);

    // ── Container-level sizing ──────────────────────────────────────────
    // preferred acts as minimum when no explicit minimum is given.
    // minContW is intentionally NOT applied here — it is handled inside
    // _buildContent so the layout engine can use it as the effective width
    // (enabling expandX/gap to work correctly at the minimum width) and
    // wrap in a horizontal scroll view when the window is narrower.
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

    _scheduleReferenceCacheRefresh();
    _scheduleReferenceRelayoutIfNeeded();

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

  void _scheduleReferenceRelayoutIfNeeded() {
    if (!_hasUnresolvedReference || _referenceRelayoutScheduled) return;
    _referenceRelayoutScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _referenceRelayoutScheduled = false;
      if (!mounted) return;
      setState(() {});
    });
  }

  void _scheduleReferenceCacheRefresh() {
    if (_referenceCacheRefreshScheduled) return;
    _referenceCacheRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _referenceCacheRefreshScheduled = false;
      if (!mounted) return;

      final ownRenderObject = context.findRenderObject();
      final ownBox = ownRenderObject is RenderBox ? ownRenderObject : null;
      if (ownBox == null || !ownBox.hasSize) return;

      bool changed = false;
      for (final key in _componentKeys()) {
        if (key is! GlobalKey) continue;
        final refContext = key.currentContext;
        final refRenderObject = refContext?.findRenderObject();
        if (refRenderObject is! RenderBox || !refRenderObject.hasSize) continue;

        final size = refRenderObject.size;
        final topLeft = ownBox.globalToLocal(
          refRenderObject.localToGlobal(Offset.zero),
        );
        final rect = topLeft & size;

        if (!_isSameSize(_referenceSizeCache[key], size)) {
          _referenceSizeCache[key] = size;
          changed = true;
        }
        if (!_isSameRect(_referenceRectCache[key], rect)) {
          _referenceRectCache[key] = rect;
          changed = true;
        }
      }

      if (changed && mounted) setState(() {});
    });
  }

  Iterable<Key> _componentKeys() sync* {
    for (final row in widget.rows) {
      for (final component in row.components) {
        final key = component.componentKey;
        if (key != null) yield key;
      }
    }
  }

  bool _isSameSize(Size? a, Size b) {
    if (a == null) return false;
    return (a.width - b.width).abs() < _geometryEpsilon &&
        (a.height - b.height).abs() < _geometryEpsilon;
  }

  bool _isSameRect(Rect? a, Rect b) {
    if (a == null) return false;
    return (a.left - b.left).abs() < _geometryEpsilon &&
        (a.top - b.top).abs() < _geometryEpsilon &&
        (a.width - b.width).abs() < _geometryEpsilon &&
        (a.height - b.height).abs() < _geometryEpsilon;
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
    // Effective minimum container width: preferred acts as minimum when no
    // explicit minimum is given. Handled here (not in the outer ConstrainedBox)
    // so the layout engine uses this width for expandX/gap distribution and can
    // wrap in a horizontal scroll view when the window is narrower.
    final minContW = (widget.minimumContainerSize?.width ??
            widget.preferredContainerSize?.width ??
            0.0)
        .clamp(0.0, double.maxFinite);

    return LayoutBuilder(
      builder: (context, constraints) {
        final rawMaxW =
            constraints.hasBoundedWidth ? constraints.maxWidth : 0.0;
        // Use the larger of the real available width and the minimum container
        // width so rows lay out as if they have at least minContW space.
        final effectiveMaxW = math.max(rawMaxW, minContW);
        final canExpandHorizontally = effectiveMaxW > 0;
        final canExpandVertically = constraints.hasBoundedHeight;
        final useMaxVertical =
            (hasExpandY || hasGapRows) && canExpandVertically;
        // True when content is wider than the window (scroll mode).
        final needsHorizontalScroll =
            !widget.scrollableX &&
            minContW > 0 &&
            constraints.hasBoundedWidth &&
            rawMaxW < minContW;

        final List<Widget> rowWidgets = [];

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

          rowWidgets.add(
            _buildRow(
              row: row,
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
          // Freeze width at minContW and allow the window to scroll over it.
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

  Widget _buildRow({
    required AclRow row,
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

    final fittedWidths = (availableWidth != null && availableWidth.isFinite)
        ? _computeFittedWidths(row: row, availableWidth: availableWidth)
        : null;

    // Gap slot distribution
    double totalFitted = 0;
    if (hasGapSlots && availableWidth != null && availableWidth.isFinite) {
      for (int i = 0; i < row.components.length; i++) {
        final comp = row.components[i];
        if (comp.isGap) continue;
        final fw = fittedWidths?[i];
        if (fw != null) {
          totalFitted += fw;
        } else {
          totalFitted += comp.preferredSize?.width ?? 0;
        }
      }
    }
    final double gapRemaining = hasGapSlots && availableWidth != null
        ? math.max(0, availableWidth - totalFitted)
        : 0;
    final double gapWeightSum = hasGapSlots
        ? row.components
            .where((c) => c.isGap)
            .fold(0.0, (s, c) => s + c.gapWeight)
        : 0;

    final children = <Widget>[];
    double plannedX = 0;
    double minHorizontalX = 0;
    double maxHorizontalX = 0;
    double rowEstimatedWidth = 0;
    double minVerticalOffset = 0;
    double maxVerticalExtent = 0;
    double rowEstimatedHeight = 0;
    final virtualRects = <Key, Rect>{};
    int componentIndex = -1;

    for (final component in row.components) {
      componentIndex++;

      // ── Gap slot ──────────────────────────────────────────────────────────
      if (component.isGap) {
        if (!widget.scrollableX && gapWeightSum > 0) {
          if (rowFillsWidth) {
            // Normalize gap flex against expandX flex so that gap(weight:1)
            // competes on the same scale as expandX components.
            // When no expandX is in the row, use the classic 10000 scale.
            final totalExpandXFlex = hasExpandX
                ? row.components
                    .where((c) => c.expandX && !c.isGap)
                    .fold(0.0, (s, c) {
                    final pref = c.preferredSize?.width ?? 0.0;
                    final min = c.minimumSize?.width ?? 0.0;
                    final diff = pref - min;
                    return s + (diff > 0 && diff.isFinite ? diff : 1000.0);
                  })
                : 0.0;
            final int flex;
            if (totalExpandXFlex > 0) {
              // Scale gap weight proportionally to total expandX flex.
              flex = ((component.gapWeight / gapWeightSum) * totalExpandXFlex)
                  .round()
                  .clamp(1, 100000);
            } else {
              flex = (component.gapWeight / gapWeightSum * 10000)
                  .round()
                  .clamp(1, 10000);
            }
            children.add(Spacer(flex: flex));
          } else {
            final gapWidth =
                (gapRemaining * component.gapWeight / gapWeightSum)
                    .clamp(0.0, double.infinity);
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

      final bool hasExplicitXAlignment = component.alignXToKey != null;
      final bool collapseToVisual =
          !isFlexNativeChild &&
          !hasExplicitXAlignment &&
          maxHorizontalX < plannedX;

      if (component.gapBefore > 0 && !collapseToVisual) {
        children.add(SizedBox(width: component.gapBefore));
        plannedX += component.gapBefore;
      }

      final resolvedLinkedWidth = component.useOtherDimX
          ? (_resolveReferenceWidth(component.referenceKey) ??
              _resolveReferencedRect(component.alignXToKey)?.width)
          : null;
      final resolvedLinkedHeight = component.useOtherDimY
          ? _resolveReferenceHeight(component.referenceKey)
          : null;

      final double alignmentDelta = collapseToVisual
          ? (maxHorizontalX + component.gapBefore - plannedX)
          : _computeHorizontalAlignmentDelta(
              component: component,
              plannedX: plannedX,
              resolvedLinkedWidth: resolvedLinkedWidth,
              virtualRects: virtualRects,
            );

      if (alignmentDelta > 0) {
        children.add(SizedBox(width: alignmentDelta));
        plannedX += alignmentDelta;
      }

      Widget child = component.child;

      final linkedWidth = resolvedLinkedWidth;
      final linkedHeight = resolvedLinkedHeight;
      // Default: minimum = preferred size when no explicit minimum is set;
      // maximum = unlimited when not set.
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
          ? (linkedWidth ?? component.maximumSize?.width ??
              (availableWidth?.isFinite == true ? availableWidth : null))
          : component.maximumSize?.width;
      final maxHeight = component.useOtherDimY
          ? (linkedHeight ?? component.maximumSize?.height)
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

      if (!isFlexNativeChild &&
          (!component.expandX || !canExpandHorizontally)) {
        final effectiveWidth =
            fittedWidths?[componentIndex] ?? component.preferredSize?.width;
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

      final hasFiniteMaxWidth =
          (component.maximumSize?.width ?? double.infinity).isFinite;
      if (!isFlexNativeChild &&
          component.expandX &&
          canExpandHorizontally &&
          !hasFiniteMaxWidth) {
        child = SizedBox(width: double.infinity, child: child);
      }

      final estimatedHeight =
          _estimateComponentHeight(component, linkedHeight);
      rowEstimatedHeight = math.max(rowEstimatedHeight, estimatedHeight);
      final estimatedWidth = _estimateComponentWidth(
        component,
        linkedWidth,
        fittedWidth: fittedWidths?[componentIndex],
      );

      final shiftedLeftInRow =
          plannedX + (alignmentDelta < 0 ? alignmentDelta : 0);
      final shiftedRightInRow = shiftedLeftInRow + estimatedWidth;
      minHorizontalX = math.min(minHorizontalX, shiftedLeftInRow);
      maxHorizontalX = math.max(maxHorizontalX, shiftedRightInRow);
      rowEstimatedWidth =
          math.max(rowEstimatedWidth, plannedX + estimatedWidth);

      final componentKey = component.componentKey;
      if (componentKey != null) {
        virtualRects[componentKey] = Rect.fromLTWH(
          shiftedLeftInRow, 0, estimatedWidth, estimatedHeight,
        );
      }

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

      final verticalAlignmentOffset = _computeVerticalAlignmentOffset(component);

      final baseTopInRow = hasExpandY && canExpandVertically
          ? 0.0
          : (rowEstimatedHeight - estimatedHeight) / 2;
      final shiftedTopInRow = baseTopInRow + verticalAlignmentOffset;
      final shiftedBottomInRow = shiftedTopInRow + estimatedHeight;

      minVerticalOffset = math.min(minVerticalOffset, shiftedTopInRow);
      maxVerticalExtent = math.max(maxVerticalExtent, shiftedBottomInRow);

      if (componentKey != null) {
        _appliedHorizontalOffsetByKey[componentKey] =
            (!isFlexNativeChild && alignmentDelta < 0) ? alignmentDelta : 0;
        _appliedVerticalOffsetByKey[componentKey] = verticalAlignmentOffset;
      }
      if (!isFlexNativeChild && verticalAlignmentOffset != 0) {
        child = Transform.translate(
          offset: Offset(0, verticalAlignmentOffset), child: child,
        );
      }

      if (component.expandX && canExpandHorizontally) {
        final hasOwnFlexParentData = child is Flexible || child is Spacer;
        if (!hasOwnFlexParentData) {
          final minW =
              (component.minimumSize?.width ?? linkedWidth ?? 0)
                  .clamp(0.0, double.maxFinite);
          final prefW = (fittedWidths?[componentIndex] ??
                  component.preferredSize?.width ?? minW)
              .clamp(minW, double.maxFinite);
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
                        constraints:
                            BoxConstraints(maxWidth: constraints.maxWidth),
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
        mainAxisAlignment:
            hasGapSlots ? MainAxisAlignment.start : mainAxisAlignment,
        crossAxisAlignment: hasExpandY && canExpandVertically
            ? CrossAxisAlignment.stretch
            : CrossAxisAlignment.center,
        mainAxisSize: rowFillsWidth && canExpandHorizontally
            ? MainAxisSize.max
            : MainAxisSize.min,
        children: children,
      );
    }

    final double extraTop = minVerticalOffset < 0 ? -minVerticalOffset : 0.0;
    final extraBottom =
        math.max(0.0, maxVerticalExtent - rowEstimatedHeight);
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
        final linkedHeight = component.useOtherDimY
            ? _resolveReferenceHeight(component.referenceKey)
            : null;
        final minH =
            (component.minimumSize?.height ?? linkedHeight ?? 0)
                .clamp(0, double.infinity);
        final prefH =
            (component.preferredSize?.height ?? minH).clamp(minH, double.infinity);
        rowFlex = (rowFlex + (prefH - minH).round()).clamp(1, 10000);
      }
      return Flexible(flex: rowFlex, fit: FlexFit.tight, child: rowWidget);
    }

    return rowWidget;
  }

  // ── Reference resolution ──────────────────────────────────────────────────

  Size? _resolveReferencedSize(Key? key) {
    if (key == null) return null;
    final cached = _referenceSizeCache[key];
    if (cached != null) return cached;
    final ctx = _resolveKeyContext(key);
    if (ctx == null) {
      _hasUnresolvedReference = true;
      return cached;
    }
    final ro = ctx.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) {
      _hasUnresolvedReference = true;
      return cached;
    }
    _referenceSizeCache[key] = ro.size;
    return ro.size;
  }

  double? _resolveReferenceWidth(Key? key) {
    final s = _resolveReferencedSize(key);
    if (s != null) return s.width;
    return _resolveReferencedRect(key)?.width;
  }

  double? _resolveReferenceHeight(Key? key) {
    final s = _resolveReferencedSize(key);
    if (s != null) return s.height;
    return _resolveReferencedRect(key)?.height;
  }

  Rect? _resolveReferencedRect(Key? key) {
    if (key == null) return null;
    final cached = _referenceRectCache[key];
    if (cached != null) return cached;

    final ownRO = context.findRenderObject();
    final ownBox = ownRO is RenderBox ? ownRO : null;
    final refCtx = _resolveKeyContext(key);
    if (ownBox == null || refCtx == null) {
      _hasUnresolvedReference = true;
      return cached;
    }
    final refRO = refCtx.findRenderObject();
    if (refRO is! RenderBox || !refRO.hasSize || !ownBox.hasSize) {
      _hasUnresolvedReference = true;
      return cached;
    }
    final topLeft = ownBox.globalToLocal(refRO.localToGlobal(Offset.zero));
    final rect = topLeft & refRO.size;
    _referenceRectCache[key] = rect;
    return rect;
  }

  BuildContext? _resolveKeyContext(Key key) {
    if (key is GlobalKey) return key.currentContext;
    try {
      final dynamic dk = key;
      final dynamic c = dk.currentContext;
      if (c is BuildContext) return c;
    } catch (_) {}
    return null;
  }

  // ── Fitted width calculation ──────────────────────────────────────────────

  Map<int, double>? _computeFittedWidths({
    required AclRow row,
    required double availableWidth,
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

      final linkedW = comp.useOtherDimX
          ? (_resolveReferenceWidth(comp.referenceKey) ??
              _resolveReferencedRect(comp.alignXToKey)?.width)
          : null;

      final bool collapseToVisual = comp.alignXToKey == null && maxHX < plannedX;
      if (comp.gapBefore > 0 && !collapseToVisual) plannedX += comp.gapBefore;

      final delta = collapseToVisual
          ? (maxHX + comp.gapBefore - plannedX)
          : _computeHorizontalAlignmentDelta(
              component: comp,
              plannedX: plannedX,
              resolvedLinkedWidth: linkedW,
              virtualRects: vRects,
            );

      if (delta > 0) plannedX += delta;

      final pref = (linkedW ??
              comp.preferredSize?.width ?? comp.minimumSize?.width ?? 0)
          .clamp(0.0, double.infinity);
      prefWidths[i] = pref;

      final h = (comp.preferredSize?.height ?? comp.minimumSize?.height ?? 0)
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
      // ── Grow phase ──────────────────────────────────────────────────────
      // When no component claims exclusive rights to surplus space (expandX /
      // gap slot), distribute the surplus proportionally across all components
      // up to their declared maximum widths.  Components without a finite
      // maximumSize do not participate in growth (they stay at preferred).
      final hasRowFiller =
          row.components.any((c) => (c.expandX && !c.isGap) || c.isGap);
      if (!hasRowFiller) {
        final surplus = availableWidth - naturalWidth;
        double growCap = 0;
        for (int i = 0; i < row.components.length; i++) {
          final comp = row.components[i];
          if (skip(comp)) continue;
          final max = comp.maximumSize?.width;
          if (max == null || !max.isFinite) continue;
          growCap += math.max(0.0, max - (prefWidths[i] ?? 0.0));
        }
        if (growCap >= 1) {
          final ratio = (surplus / growCap).clamp(0.0, 1.0);
          final grown = <int, double>{};
          for (int i = 0; i < row.components.length; i++) {
            final comp = row.components[i];
            if (skip(comp)) continue;
            // Natural-sized widgets (no hints) are not constrained.
            if (comp.preferredSize == null &&
                comp.minimumSize == null &&
                comp.maximumSize == null &&
                !comp.useOtherDimX) {
              continue;
            }
            final pref = prefWidths[i] ?? 0.0;
            final max = comp.maximumSize?.width;
            final canGrow = (max != null && max.isFinite)
                ? math.max(0.0, max - pref)
                : 0.0;
            grown[i] = pref + canGrow * ratio;
          }
          return grown;
        }
      }
      return null;
    }

    final deficit = naturalWidth - availableWidth;
    double shrinkCap = 0;
    for (int i = 0; i < row.components.length; i++) {
      final comp = row.components[i];
      if (skip(comp)) continue;
      shrinkCap += math.max(0.0, (prefWidths[i] ?? 0) - (comp.minimumSize?.width ?? comp.preferredSize?.width ?? 0));
    }
    if (shrinkCap < 1) return null;

    final ratio = (deficit / shrinkCap).clamp(0.0, 1.0);
    final fitted = <int, double>{};
    for (int i = 0; i < row.components.length; i++) {
      final comp = row.components[i];
      if (skip(comp)) continue;
      // Components with no ACL size hints at all render at their natural
      // intrinsic / widget-defined size. Do NOT insert them into the fitted
      // map so that _buildRow will not wrap them in SizedBox(width: 0).
      if (comp.preferredSize == null &&
          comp.minimumSize == null &&
          !comp.useOtherDimX) {
        continue;
      }
      final pref = prefWidths[i] ?? 0.0;
      final min = comp.minimumSize?.width ?? 0.0;
      fitted[i] = pref - math.max(0.0, pref - min) * ratio;
    }
    return fitted;
  }

  // ── Width / height estimation ─────────────────────────────────────────────

  double _estimateComponentWidth(
    AclComponent component,
    double? linkedWidth, {
    double? fittedWidth,
  }) {
    if (fittedWidth != null) return fittedWidth.clamp(0, double.infinity).toDouble();
    final mw = _resolveReferenceWidth(component.componentKey);
    if (mw != null) return mw.clamp(0, double.infinity).toDouble();
    return (linkedWidth ?? component.preferredSize?.width ??
            component.minimumSize?.width ?? 0)
        .clamp(0, double.infinity)
        .toDouble();
  }

  double _estimateComponentHeight(AclComponent component, double? linkedHeight) {
    final mh = _resolveReferenceHeight(component.componentKey);
    if (mh != null) return mh.clamp(0, double.infinity).toDouble();
    return (linkedHeight ?? component.preferredSize?.height ??
            component.minimumSize?.height ?? 0)
        .clamp(0, double.infinity)
        .toDouble();
  }

  // ── Alignment delta computation ───────────────────────────────────────────

  double _computeHorizontalAlignmentDelta({
    required AclComponent component,
    required double plannedX,
    required double? resolvedLinkedWidth,
    required Map<Key, Rect> virtualRects,
  }) {
    if (component.alignXToKey == null ||
        component.alignXFrom == null ||
        component.alignXTo == null) {
      return 0;
    }

    final key = component.alignXToKey;
    final virtualRefRect = key != null ? virtualRects[key] : null;
    final refRect = virtualRefRect ?? _resolveReferencedRect(key);
    if (refRect == null) {
      _hasUnresolvedReference = true;
      return 0;
    }

    final refOffset = key == null ? 0.0 : (_appliedHorizontalOffsetByKey[key] ?? 0.0);
    final unshiftedRefRect = virtualRefRect != null || refOffset == 0
        ? refRect
        : refRect.translate(-refOffset, 0);

    final widthEstimate = _estimateComponentWidth(
      component, resolvedLinkedWidth ?? refRect.width,
    );
    final currentLocalPoint =
        plannedX + _horizontalOffset(component.alignXFrom!, widthEstimate);
    final targetLocalPoint =
        _horizontalPoint(unshiftedRefRect, component.alignXTo!);
    return (targetLocalPoint - component.alignXGap) - currentLocalPoint;
  }

  double _computeVerticalAlignmentOffset(AclComponent component) {
    if (component.componentKey == null ||
        component.alignYToKey == null ||
        component.alignYFrom == null ||
        component.alignYTo == null) {
      return 0;
    }

    final selfRect = _resolveReferencedRect(component.componentKey);
    final refRect = _resolveReferencedRect(component.alignYToKey);
    if (selfRect == null || refRect == null) {
      _hasUnresolvedReference = true;
      return 0;
    }

    final previousOffset =
        _appliedVerticalOffsetByKey[component.componentKey] ?? 0;
    final unshiftedSelfRect = previousOffset == 0
        ? selfRect
        : selfRect.translate(0, -previousOffset);

    final currentPoint = _verticalPoint(unshiftedSelfRect, component.alignYFrom!);
    final targetPoint = _verticalPoint(refRect, component.alignYTo!);
    return (targetPoint - component.alignYGap) - currentPoint;
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
