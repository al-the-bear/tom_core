/// The widgets the layout is handed back as: [AclLayout], the [Acl] that adds
/// a title band, and the render-layer box that lets an auto-defaulted
/// component report its minimum intrinsic width and clip rather than overflow.
///
/// See `acl_container.dart` for why these are parts rather than libraries.
part of 'acl_container.dart';

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
  const _AclFloorWidthBox({
    required this.onMinWidth,
    required Widget super.child,
  });

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
    final allocated = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : minWidth;
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
      (innerContext, innerOffset) =>
          innerContext.paintChild(child, innerOffset),
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
