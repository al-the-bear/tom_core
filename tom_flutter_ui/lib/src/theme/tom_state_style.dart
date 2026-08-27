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
  /// Opacity applied to the content, from 0.0 (invisible) to 1.0 (opaque).
  /// Set it to 1.0 to disable dimming. Values outside that range are rejected
  /// by the constructor: this is a fraction, not a percentage, and 60 written
  /// for "60 %" would otherwise dim nothing at all.
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

  /// Creates a style. [opacity] must be within 0.0..1.0 inclusive.
  ///
  /// The range is checked here rather than left to Flutter because both ways
  /// of getting it wrong were previously silent at the call site: a negative
  /// value reached [Opacity] and failed inside `basic.dart`, naming a frame
  /// the caller never wrote, while a value above 1.0 was accepted and then
  /// ignored, since [apply] only dims when the opacity is below 1.0. Being a
  /// `const` constructor, this rejects the out-of-range literal at compile
  /// time — which is where nearly every style in an app is written.
  const TomStateStyle({
    this.opacity = 0.6,
    this.absorbPointers = true,
    this.colorOverlay,
    this.builder,
  }) : assert(opacity >= 0.0 && opacity <= 1.0,
            'opacity must be within 0.0..1.0 (a fraction, not a percentage)');

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
