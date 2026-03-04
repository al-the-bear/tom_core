import 'package:flutter/material.dart';

import 'acl_flags.dart';
import 'row_alignment.dart';

enum AclBorderLineKind { single, doubleLine }

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
  final Key? referenceKey;
  final Key? componentKey;

  const AclComponent({
    required this.child,
    this.flags = 0,
    this.gapBefore = 0,
    this.preferredSize,
    this.minimumSize,
    this.referenceKey,
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
  final FocusNode _focusNode = FocusNode();
  bool _hasFocusWithin = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget content = _buildContent(context);

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
        boxShadow: style.withShadow
            ? [
                BoxShadow(
                  color: shadowColor.withValues(alpha: 0.35),
                  offset: const Offset(0, 2),
                  blurRadius: 6,
                ),
              ]
            : null,
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
          boxShadow: style.withShadow
              ? [
                  BoxShadow(
                    color: shadowColor.withValues(alpha: 0.35),
                    offset: const Offset(0, 2),
                    blurRadius: 6,
                  ),
                ]
              : null,
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
    for (final component in row.components) {
      if (component.gapBefore > 0) {
        children.add(SizedBox(width: component.gapBefore));
      }

      Widget child = component.child;

      if (component.minimumSize != null || component.preferredSize != null) {
        child = ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: component.minimumSize?.width ?? 0,
            minHeight: component.minimumSize?.height ?? 0,
            maxWidth: component.preferredSize?.width ?? double.infinity,
            maxHeight: component.preferredSize?.height ?? double.infinity,
          ),
          child: child,
        );
      }

      if (component.componentKey != null) {
        child = KeyedSubtree(key: component.componentKey, child: child);
      }

      if (component.expandX && canExpandHorizontally) {
        final hasOwnFlexParentData = child is Flexible || child is Spacer;
        if (!hasOwnFlexParentData) {
          child = Flexible(fit: FlexFit.tight, child: child);
        }
      }

      children.add(child);
    }

    Widget rowWidget;

    if (!hasExpandX && canExpandHorizontally) {
      rowWidget = LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                mainAxisAlignment: mainAxisAlignment,
                crossAxisAlignment: hasExpandY && canExpandVertically
                    ? CrossAxisAlignment.stretch
                    : CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: children,
              ),
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

    if (hasExpandY && canExpandVertically) {
      return Flexible(fit: FlexFit.tight, child: rowWidget);
    }

    return rowWidget;
  }
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
  const Acl({
    super.key,
    required super.rows,
    super.borderStyle = const AclBorderStyle.none(),
    super.focusedBorderStyle,
    super.padding = EdgeInsets.zero,
    super.backgroundColor,
  });
}

enum AclGroupTitlePosition { topLeft, topCenter, topRight }

class AclGroup extends StatelessWidget {
  final String? title;
  final Widget child;
  final AclBorderStyle borderStyle;
  final AclBorderStyle? focusedBorderStyle;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final TextStyle? titleStyle;
  final AclGroupTitlePosition titlePosition;

  const AclGroup({
    super.key,
    this.title,
    required this.child,
    this.borderStyle = const AclBorderStyle(
      lineKind: AclBorderLineKind.doubleLine,
      with3dEffect: true,
    ),
    this.focusedBorderStyle,
    this.padding = const EdgeInsets.all(8),
    this.backgroundColor,
    this.titleStyle,
    this.titlePosition = AclGroupTitlePosition.topLeft,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleTextStyle =
        titleStyle ??
        theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);

    if (title == null || title!.isEmpty) {
      return AclContainer(
        rows: [
          AclRow(
            components: [AclComponent(child: child, flags: AclFlags.expandX)],
          ),
        ],
        borderStyle: borderStyle,
        focusedBorderStyle: focusedBorderStyle,
        padding: padding,
        backgroundColor: backgroundColor,
      );
    }

    final bg = backgroundColor ?? theme.scaffoldBackgroundColor;

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: AclContainer(
            rows: [
              AclRow(
                components: [
                  AclComponent(child: child, flags: AclFlags.expandX),
                ],
              ),
            ],
            borderStyle: borderStyle,
            focusedBorderStyle: focusedBorderStyle,
            padding: padding.add(const EdgeInsets.only(top: 8)),
            backgroundColor: backgroundColor,
          ),
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

  Alignment _alignment() => switch (titlePosition) {
    AclGroupTitlePosition.topLeft => Alignment.centerLeft,
    AclGroupTitlePosition.topCenter => Alignment.center,
    AclGroupTitlePosition.topRight => Alignment.centerRight,
  };

  double? _left() => switch (titlePosition) {
    AclGroupTitlePosition.topLeft => 12,
    AclGroupTitlePosition.topCenter => 0,
    AclGroupTitlePosition.topRight => null,
  };

  double? _right() => switch (titlePosition) {
    AclGroupTitlePosition.topLeft => null,
    AclGroupTitlePosition.topCenter => 0,
    AclGroupTitlePosition.topRight => 12,
  };
}
