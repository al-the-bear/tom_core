import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'acl_flags.dart';
import 'row_alignment.dart';

enum AclBorderLineKind { single, doubleLine }

enum AclAxisPointX { left, center, right }

enum AclAxisPointY { top, center, bottom }

enum AclRowCrossAlignment { top, center, bottom }

class AclBorderStyle {
  final bool enabled;
  final bool rounded;
  final double borderRadius;
  final double lineWidth;
  final AclBorderLineKind lineKind;
  final bool withShadow;
  final bool with3dEffect;
  final Color primaryColor;
  final Color? secondaryColor;
  final Color? shadowColor;
  final EdgeInsetsGeometry borderInsets;

  const AclBorderStyle({
    this.enabled = true,
    this.rounded = false,
    this.borderRadius = 6,
    this.lineWidth = 1,
    this.lineKind = AclBorderLineKind.single,
    this.withShadow = false,
    this.with3dEffect = false,
    this.primaryColor = const Color(0xFF9E9E9E),
    this.secondaryColor,
    this.shadowColor,
    this.borderInsets = const EdgeInsets.all(8),
  });

  const AclBorderStyle.none()
    : enabled = false,
      rounded = false,
      borderRadius = 0,
      lineWidth = 0,
      lineKind = AclBorderLineKind.single,
      withShadow = false,
      with3dEffect = false,
      primaryColor = Colors.transparent,
      secondaryColor = null,
      shadowColor = null,
      borderInsets = EdgeInsets.zero;

  AclBorderStyle copyWith({
    bool? enabled,
    bool? rounded,
    double? borderRadius,
    double? lineWidth,
    AclBorderLineKind? lineKind,
    bool? withShadow,
    bool? with3dEffect,
    Color? primaryColor,
    Color? secondaryColor,
    Color? shadowColor,
    EdgeInsetsGeometry? borderInsets,
  }) {
    return AclBorderStyle(
      enabled: enabled ?? this.enabled,
      rounded: rounded ?? this.rounded,
      borderRadius: borderRadius ?? this.borderRadius,
      lineWidth: lineWidth ?? this.lineWidth,
      lineKind: lineKind ?? this.lineKind,
      withShadow: withShadow ?? this.withShadow,
      with3dEffect: with3dEffect ?? this.with3dEffect,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      shadowColor: shadowColor ?? this.shadowColor,
      borderInsets: borderInsets ?? this.borderInsets,
    );
  }
}

class AclComponent {
  final Widget child;
  final int flags;
  final double gapBefore;
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

class AclRow {
  final List<AclComponent> components;
  final RowAlignment alignment;
  final double gapBefore;

  const AclRow({
    required this.components,
    this.alignment = RowAlignment.left,
    this.gapBefore = 0,
  });
}

class AclContainer extends StatefulWidget {
  final List<AclRow> rows;
  final AclBorderStyle borderStyle;
  final AclBorderStyle? focusedBorderStyle;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;

  const AclContainer({
    super.key,
    required this.rows,
    this.borderStyle = const AclBorderStyle.none(),
    this.focusedBorderStyle,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
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
        if (_hasFocusWithin == hasFocus || !mounted) {
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _hasFocusWithin == hasFocus) {
            return;
          }
          setState(() {
            _hasFocusWithin = hasFocus;
          });
        });
      },
      child: content,
    );
  }

  void _scheduleReferenceRelayoutIfNeeded() {
    if (!_hasUnresolvedReference || _referenceRelayoutScheduled) {
      return;
    }

    _referenceRelayoutScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _referenceRelayoutScheduled = false;
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  void _scheduleReferenceCacheRefresh() {
    if (_referenceCacheRefreshScheduled) {
      return;
    }

    _referenceCacheRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _referenceCacheRefreshScheduled = false;
      if (!mounted) {
        return;
      }

      final ownRenderObject = context.findRenderObject();
      final ownBox = ownRenderObject is RenderBox ? ownRenderObject : null;
      if (ownBox == null || !ownBox.hasSize) {
        return;
      }

      bool changed = false;
      for (final key in _componentKeys()) {
        if (key is! GlobalKey) {
          continue;
        }
        final refContext = key.currentContext;
        final refRenderObject = refContext?.findRenderObject();
        if (refRenderObject is! RenderBox || !refRenderObject.hasSize) {
          continue;
        }

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

      if (changed && mounted) {
        setState(() {});
      }
    });
  }

  Iterable<Key> _componentKeys() sync* {
    for (final row in widget.rows) {
      for (final component in row.components) {
        final key = component.componentKey;
        if (key != null) {
          yield key;
        }
      }
    }
  }

  bool _isSameSize(Size? a, Size b) {
    if (a == null) {
      return false;
    }
    return (a.width - b.width).abs() < _geometryEpsilon &&
        (a.height - b.height).abs() < _geometryEpsilon;
  }

  bool _isSameRect(Rect? a, Rect b) {
    if (a == null) {
      return false;
    }
    return (a.left - b.left).abs() < _geometryEpsilon &&
        (a.top - b.top).abs() < _geometryEpsilon &&
        (a.width - b.width).abs() < _geometryEpsilon &&
        (a.height - b.height).abs() < _geometryEpsilon;
  }

  Widget _wrapWithBorder(Widget content, AclBorderStyle style) {
    final hasBackground = widget.backgroundColor != null;

    if (!style.enabled) {
      if (!hasBackground) {
        return content;
      }
      return Container(color: widget.backgroundColor, child: content);
    }

    final baseColor = style.primaryColor;
    final accentColor =
        style.secondaryColor ?? Color.lerp(baseColor, Colors.white, 0.35)!;
    final dark3d = Color.lerp(baseColor, Colors.black, 0.35)!;
    final light3d = Color.lerp(baseColor, Colors.white, 0.45)!;
    final radius = style.rounded ? style.borderRadius : 0.0;
    final shadowColor =
        style.shadowColor ?? Color.lerp(baseColor, Colors.black, 0.55)!;

    final border = style.with3dEffect
        ? Border(
            top: BorderSide(color: light3d, width: style.lineWidth),
            left: BorderSide(color: light3d, width: style.lineWidth),
            right: BorderSide(color: dark3d, width: style.lineWidth),
            bottom: BorderSide(color: dark3d, width: style.lineWidth),
          )
        : Border.all(color: baseColor, width: style.lineWidth);

    final contentWithInsets = Padding(
      padding: style.borderInsets,
      child: content,
    );

    Widget decorated = Container(
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        border: border,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: contentWithInsets,
    );

    if (style.lineKind == AclBorderLineKind.doubleLine) {
      final innerRadius = radius > 0
          ? (radius - 2).clamp(0.0, radius).toDouble()
          : 0.0;
      decorated = Container(
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          border: Border.all(color: baseColor, width: style.lineWidth),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Padding(
          padding: EdgeInsets.all(style.lineWidth + 2),
          child: Container(
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              border: Border.all(color: accentColor, width: style.lineWidth),
              borderRadius: BorderRadius.circular(innerRadius),
            ),
            child: contentWithInsets,
          ),
        ),
      );
    }

    if (style.withShadow) {
      final blurExtent = (style.lineWidth * 4).clamp(3.0, 10.0);
      final shadowStart = shadowColor.withValues(alpha: 0.28);
      final shadowEnd = shadowColor.withValues(alpha: 0.0);

      decorated = Stack(
        clipBehavior: Clip.none,
        children: [
          decorated,
          Positioned(
            top: style.lineWidth,
            bottom: style.lineWidth,
            right: -blurExtent,
            width: blurExtent,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [shadowStart, shadowEnd],
                  ),
                  borderRadius: BorderRadius.horizontal(
                    right: Radius.circular(radius > 0 ? radius : 2),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: style.lineWidth,
            right: style.lineWidth,
            bottom: -blurExtent,
            height: blurExtent,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [shadowStart, shadowEnd],
                  ),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(radius > 0 ? radius : 2),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return decorated;
  }

  Widget _buildContent(BuildContext context) {
    final hasExpandY = widget.rows.any(
      (row) => row.components.any((component) => component.expandY),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final canExpandHorizontally = constraints.hasBoundedWidth;
        final canExpandVertically = constraints.hasBoundedHeight;

        final List<Widget> rowWidgets = [];
        for (final row in widget.rows) {
          if (row.gapBefore > 0) {
            rowWidgets.add(SizedBox(height: row.gapBefore));
          }
          rowWidgets.add(
            _buildRow(
              row: row,
              canExpandHorizontally: canExpandHorizontally,
              canExpandVertically: canExpandVertically,
            ),
          );
        }

        Widget column = Column(
          mainAxisSize: hasExpandY && canExpandVertically
              ? MainAxisSize.max
              : MainAxisSize.min,
          crossAxisAlignment: canExpandHorizontally
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.start,
          children: rowWidgets,
        );

        if (!canExpandHorizontally) {
          column = UnconstrainedBox(
            alignment: Alignment.topLeft,
            child: column,
          );
        }

        return column;
      },
    );
  }

  Widget _buildRow({
    required AclRow row,
    required bool canExpandHorizontally,
    required bool canExpandVertically,
  }) {
    final mainAxisAlignment = switch (row.alignment) {
      RowAlignment.left => MainAxisAlignment.start,
      RowAlignment.center => MainAxisAlignment.center,
      RowAlignment.right => MainAxisAlignment.end,
    };

    final hasExpandX = row.components.any((component) => component.expandX);
    final hasExpandY = row.components.any((component) => component.expandY);

    final children = <Widget>[];
    double plannedX = 0;
    double minHorizontalX = 0;
    double maxHorizontalX = 0;
    double rowEstimatedWidth = 0;
    double minVerticalOffset = 0;
    double maxVerticalExtent = 0;
    double rowEstimatedHeight = 0;
    final virtualRects = <Key, Rect>{};
    for (final component in row.components) {
      if (component.gapBefore > 0) {
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

      final alignmentDelta = _computeHorizontalAlignmentDelta(
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
      final isFlexNativeChild =
          component.child is Flexible ||
          component.child is Expanded ||
          component.child is Spacer;

      final linkedWidth = resolvedLinkedWidth;
      final linkedHeight = resolvedLinkedHeight;
      final minWidth = component.useOtherDimX
          ? (linkedWidth ?? component.minimumSize?.width)
          : component.minimumSize?.width;
      final minHeight = component.useOtherDimY
          ? (linkedHeight ?? component.minimumSize?.height)
          : component.minimumSize?.height;
      final maxWidth = component.useOtherDimX
          ? (linkedWidth ?? component.maximumSize?.width)
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
        final preferredWidth = component.preferredSize?.width;
        if (preferredWidth != null) {
          child = SizedBox(width: preferredWidth, child: child);
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

      final estimatedHeight = _estimateComponentHeight(component, linkedHeight);
      rowEstimatedHeight = math.max(rowEstimatedHeight, estimatedHeight);
      final estimatedWidth = _estimateComponentWidth(component, linkedWidth);

      final shiftedLeftInRow =
          plannedX + (alignmentDelta < 0 ? alignmentDelta : 0);
      final shiftedRightInRow = shiftedLeftInRow + estimatedWidth;
      minHorizontalX = math.min(minHorizontalX, shiftedLeftInRow);
      maxHorizontalX = math.max(maxHorizontalX, shiftedRightInRow);
      rowEstimatedWidth = math.max(
        rowEstimatedWidth,
        plannedX + estimatedWidth,
      );

      final componentKey = component.componentKey;
      if (componentKey != null) {
        virtualRects[componentKey] = Rect.fromLTWH(
          shiftedLeftInRow,
          0,
          estimatedWidth,
          estimatedHeight,
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
        child = Transform.translate(
          offset: Offset(alignmentDelta, 0),
          child: child,
        );
      }

      final verticalAlignmentOffset = _computeVerticalAlignmentOffset(
        component,
      );

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
          offset: Offset(0, verticalAlignmentOffset),
          child: child,
        );
      }

      if (component.expandX && canExpandHorizontally) {
        final hasOwnFlexParentData = child is Flexible || child is Spacer;
        if (!hasOwnFlexParentData) {
          final minW = (component.minimumSize?.width ?? linkedWidth ?? 0).clamp(
            0,
            double.infinity,
          );
          final prefW = (component.preferredSize?.width ?? minW).clamp(
            minW,
            double.infinity,
          );
          final flexWeight = ((prefW - minW).round()).clamp(1, 10000);

          child = Flexible(flex: flexWeight, fit: FlexFit.tight, child: child);
        }
      }

      children.add(child);

      plannedX += estimatedWidth;
    }

    Widget rowWidget;

    final double extraLeft = minHorizontalX < 0 ? -minHorizontalX : 0.0;

    if (!hasExpandX && canExpandHorizontally) {
      rowWidget = LayoutBuilder(
        builder: (context, constraints) {
          final rowContent = Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: hasExpandY && canExpandVertically
                ? CrossAxisAlignment.stretch
                : CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: children,
          );

          final alignment = switch (mainAxisAlignment) {
            MainAxisAlignment.end ||
            MainAxisAlignment.spaceBetween ||
            MainAxisAlignment.spaceAround ||
            MainAxisAlignment.spaceEvenly => Alignment.centerRight,
            MainAxisAlignment.center => Alignment.center,
            _ => Alignment.centerLeft,
          };

          // clipBehavior: Clip.none allows components translated to negative x
          // (via convenience placement alignment deltas) to paint into the
          // extraLeft padding area reserved by the outer Padding widget, rather
          // than being clipped at the scroll viewport's x=0 boundary.
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Align(alignment: alignment, child: rowContent),
            ),
          );
        },
      );
    } else {
      rowWidget = Row(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: hasExpandY && canExpandVertically
            ? CrossAxisAlignment.stretch
            : CrossAxisAlignment.center,
        mainAxisSize: hasExpandX && canExpandHorizontally
            ? MainAxisSize.max
            : MainAxisSize.min,
        children: children,
      );
    }

    final double extraTop = minVerticalOffset < 0 ? -minVerticalOffset : 0.0;
    final extraBottom = math.max(0.0, maxVerticalExtent - rowEstimatedHeight);
    final extraRight = hasExpandX && canExpandHorizontally
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

    // When using ScrollView+Clip.none with an extraLeft padding zone, wrap the
    // whole (Padding+ScrollView) in a ClipRect. The ClipRect clips to the
    // container's full width: the extraLeft padding area is inside those bounds
    // (visible for negatively-translated components), while content overflowing
    // to the right is clipped at the container edge.
    if (!hasExpandX && canExpandHorizontally && extraLeft > 0) {
      rowWidget = ClipRect(child: rowWidget);
    }

    if (hasExpandY && canExpandVertically) {
      int rowFlex = 1;
      for (final component in row.components) {
        if (!component.expandY) {
          continue;
        }
        final linkedHeight = component.useOtherDimY
            ? _resolveReferenceHeight(component.referenceKey)
            : null;
        final minH = (component.minimumSize?.height ?? linkedHeight ?? 0).clamp(
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

  Size? _resolveReferencedSize(Key? key) {
    if (key == null) {
      return null;
    }

    final cached = _referenceSizeCache[key];
    if (cached != null) {
      return cached;
    }

    final context = _resolveKeyContext(key);
    if (context == null) {
      _hasUnresolvedReference = true;
      return cached;
    }
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      _hasUnresolvedReference = true;
      return cached;
    }
    final size = renderObject.size;
    _referenceSizeCache[key] = size;
    return size;
  }

  double? _resolveReferenceWidth(Key? key) {
    final size = _resolveReferencedSize(key);
    if (size != null) {
      return size.width;
    }
    final rect = _resolveReferencedRect(key);
    return rect?.width;
  }

  double? _resolveReferenceHeight(Key? key) {
    final size = _resolveReferencedSize(key);
    if (size != null) {
      return size.height;
    }
    final rect = _resolveReferencedRect(key);
    return rect?.height;
  }

  Rect? _resolveReferencedRect(Key? key) {
    if (key == null) {
      return null;
    }

    final cached = _referenceRectCache[key];
    if (cached != null) {
      return cached;
    }

    final ownRenderObject = context.findRenderObject();
    final ownBox = ownRenderObject is RenderBox ? ownRenderObject : null;
    final refContext = _resolveKeyContext(key);
    if (ownBox == null || refContext == null) {
      _hasUnresolvedReference = true;
      return cached;
    }
    final refRenderObject = refContext.findRenderObject();
    if (refRenderObject is! RenderBox ||
        !refRenderObject.hasSize ||
        !ownBox.hasSize) {
      _hasUnresolvedReference = true;
      return cached;
    }
    final topLeft = ownBox.globalToLocal(
      refRenderObject.localToGlobal(Offset.zero),
    );
    final rect = topLeft & refRenderObject.size;
    _referenceRectCache[key] = rect;
    return rect;
  }

  BuildContext? _resolveKeyContext(Key key) {
    if (key is GlobalKey) {
      return key.currentContext;
    }

    try {
      final dynamic dynamicKey = key;
      final dynamic context = dynamicKey.currentContext;
      if (context is BuildContext) {
        return context;
      }
    } catch (_) {}

    return null;
  }

  double _estimateComponentWidth(AclComponent component, double? linkedWidth) {
    final measuredWidth = _resolveReferenceWidth(component.componentKey);
    if (measuredWidth != null) {
      return measuredWidth.clamp(0, double.infinity).toDouble();
    }

    return (linkedWidth ??
            component.preferredSize?.width ??
            component.minimumSize?.width ??
            0)
        .clamp(0, double.infinity)
        .toDouble();
  }

  double _estimateComponentHeight(
    AclComponent component,
    double? linkedHeight,
  ) {
    final measuredHeight = _resolveReferenceHeight(component.componentKey);
    if (measuredHeight != null) {
      return measuredHeight.clamp(0, double.infinity).toDouble();
    }

    return (linkedHeight ??
            component.preferredSize?.height ??
            component.minimumSize?.height ??
            0)
        .clamp(0, double.infinity)
        .toDouble();
  }

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

    final refOffset = key == null
        ? 0.0
        : (_appliedHorizontalOffsetByKey[key] ?? 0.0);
    final unshiftedRefRect = virtualRefRect != null || refOffset == 0
        ? refRect
        : refRect.translate(-refOffset, 0);

    final widthEstimate = _estimateComponentWidth(
      component,
      resolvedLinkedWidth ?? refRect.width,
    );
    final currentLocalPoint =
        plannedX + _horizontalOffset(component.alignXFrom!, widthEstimate);
    final targetLocalPoint = _horizontalPoint(
      unshiftedRefRect,
      component.alignXTo!,
    );
    final desiredLocalPoint = targetLocalPoint - component.alignXGap;
    return desiredLocalPoint - currentLocalPoint;
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

    final currentPoint = _verticalPoint(
      unshiftedSelfRect,
      component.alignYFrom!,
    );
    final targetPoint = _verticalPoint(refRect, component.alignYTo!);
    final desiredPoint = targetPoint - component.alignYGap;
    return desiredPoint - currentPoint;
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

  double _horizontalOffset(AclAxisPointX point, double width) =>
      switch (point) {
        AclAxisPointX.left => 0,
        AclAxisPointX.center => width / 2,
        AclAxisPointX.right => width,
      };
}

class AclLayout extends StatelessWidget {
  final List<AclRow> rows;
  final AclBorderStyle borderStyle;
  final AclBorderStyle? focusedBorderStyle;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;

  const AclLayout({
    super.key,
    required this.rows,
    this.borderStyle = const AclBorderStyle.none(),
    this.focusedBorderStyle,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return AclContainer(
      rows: rows,
      borderStyle: borderStyle,
      focusedBorderStyle: focusedBorderStyle,
      padding: padding,
      backgroundColor: backgroundColor,
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
    this.title,
    this.titleStyle,
    this.titlePosition = AclTitlePosition.topLeft,
  });

  @override
  Widget build(BuildContext context) {
    if (title == null || title!.isEmpty) {
      return super.build(context);
    }

    final theme = Theme.of(context);
    final titleTextStyle =
        titleStyle ??
        theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);
    final bg = backgroundColor ?? theme.scaffoldBackgroundColor;

    return Stack(
      children: [
        AclContainer(
          rows: rows,
          borderStyle: borderStyle,
          focusedBorderStyle: focusedBorderStyle,
          padding: padding.add(const EdgeInsets.only(top: 8)),
          backgroundColor: backgroundColor,
        ),
        Positioned(
          top: -1,
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
