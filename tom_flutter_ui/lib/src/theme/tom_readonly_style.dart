import 'package:flutter/widgets.dart';

/// Controls the visual treatment of authorization-readonly widgets.
///
/// Readonly is an authorization state — the widget is visible but not
/// interactive. This class controls **how** that looks. The default is
/// `AbsorbPointer` + 0.6 opacity, but apps can customize per-theme or
/// per-family.
class TomReadonlyStyle {
  /// Opacity applied to readonly widgets. Set to 1.0 to disable dimming.
  final double opacity;

  /// Whether pointer events are absorbed (blocked). Almost always `true` —
  /// set to `false` only if the family handles readonly at the widget level
  /// (e.g., a TextField that switches to a non-editable display).
  final bool absorbPointers;

  /// Optional color overlay applied via [ColorFiltered].
  final Color? colorOverlay;

  /// Optional custom builder that replaces the default treatment entirely.
  /// When set, [opacity], [absorbPointers], and [colorOverlay] are ignored.
  final Widget Function(Widget content)? builder;

  const TomReadonlyStyle({
    this.opacity = 0.6,
    this.absorbPointers = true,
    this.colorOverlay,
    this.builder,
  });

  /// The framework default — AbsorbPointer + 0.6 opacity.
  static const defaultStyle = TomReadonlyStyle();

  /// Applies this style to the given content widget.
  Widget apply(Widget content) {
    if (builder != null) return builder!(content);

    Widget result = content;
    if (colorOverlay != null) {
      result = ColorFiltered(
        colorFilter: ColorFilter.mode(colorOverlay!, BlendMode.srcATop),
        child: result,
      );
    }
    if (opacity < 1.0) result = Opacity(opacity: opacity, child: result);
    if (absorbPointers) result = AbsorbPointer(child: result);
    return result;
  }
}
