/// Container chrome: the border and its focused variant, a separator drawn in
/// a gap row, and a row's cross-axis alignment.
///
/// See `acl_container.dart` for why these are parts rather than libraries.
part of 'acl_container.dart';

extension _AclChrome on _AclContainerState {
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
}
