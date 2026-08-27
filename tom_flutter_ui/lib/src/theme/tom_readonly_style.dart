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
  ///
  /// **Hoist the function; do not write it inline in `build`.** This is the
  /// one field [operator ==] compares by reference — Dart offers no way to
  /// ask whether two closures behave alike — so a builder allocated during
  /// `build` makes every style unequal to the last one, and
  /// `TomThemeScope.updateShouldNotify` then rebuilds every read-only widget
  /// on every ancestor rebuild. A top-level or static function, or a field
  /// held on the state, compares equal to itself and avoids that entirely.
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

  /// Compares by value, so a style rebuilt with the same settings is the same
  /// style. See `TomTheme` for why that matters, and [builder] for the one
  /// field this cannot compare structurally.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TomReadonlyStyle &&
        other.runtimeType == runtimeType &&
        other.opacity == opacity &&
        other.absorbPointers == absorbPointers &&
        other.colorOverlay == colorOverlay &&
        other.builder == builder;
  }

  @override
  int get hashCode =>
      Object.hash(opacity, absorbPointers, colorOverlay, builder);
}
