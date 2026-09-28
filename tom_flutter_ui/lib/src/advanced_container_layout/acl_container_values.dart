/// Appearance and placement values for the ACL container: borders,
/// separators, titles, axis anchor points, direction.
///
/// A part rather than a library because privacy in Dart is per *library*, and
/// the engine, the model and the render pipeline share private declarations —
/// `_AclRowLayout`, `_AclFloorWidthBox`, and every private member of the
/// container's state. Splitting into separate libraries would mean widening
/// those to public, which is the opposite of what this split is for.
part of 'acl_container.dart';

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
