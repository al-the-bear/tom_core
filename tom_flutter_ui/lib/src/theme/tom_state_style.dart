import 'package:flutter/widgets.dart';

/// Controls the visual treatment of a non-interactive authorization state.
///
/// Two of the four `TomAuthState`s render the widget but withhold it:
/// `read` (visible, not editable) and `disabled` (visible, not available).
/// Both are Tom authorization concepts that Flutter has no equivalent for —
/// `disabled` here is not Material's `enabled: false` — and both are treated
/// the same way: dim the content and stop it receiving pointers. So one class
/// describes both, and a `TomTheme` carries one instance per state.
///
/// The two framework defaults are [readonly] and [disabled]. They differ only
/// in opacity, which is the whole reason they are separate values rather than
/// one constant: how much a widget is dimmed is what tells a user *why* it is
/// inert.
class TomStateStyle {
  /// Opacity applied to the content. Set to 1.0 to disable dimming.
  final double opacity;

  /// Whether pointer events are absorbed (blocked). Almost always `true` —
  /// set to `false` only if the family handles the state at the widget level
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

  const TomStateStyle({
    this.opacity = 0.6,
    this.absorbPointers = true,
    this.colorOverlay,
    this.builder,
  });

  /// The framework default for `read` — AbsorbPointer + 0.6 opacity.
  static const readonly = TomStateStyle();

  /// The framework default for `disabled` — AbsorbPointer + 0.38 opacity.
  ///
  /// 0.38 is Material's disabled opacity, borrowed so a Tom-disabled widget
  /// sits beside a Material-disabled one without looking wrong. It is a
  /// default, not a rule: this is a Tom authorization state, so an app that
  /// wants to distinguish "you may not" from "not right now" changes it here.
  static const disabled = TomStateStyle(opacity: 0.38);

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
    return other is TomStateStyle &&
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
