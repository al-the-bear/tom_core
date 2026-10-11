import 'package:flutter/widgets.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'tom_state_style.dart';

/// Tom-specific theme extensions that layer on top of Flutter's [ThemeData].
///
/// Tom does **not** replace Flutter's theming. Colors, typography, shapes,
/// elevation, disabled styling, dark/light mode, and per-widget theme data
/// are all handled by Flutter's [Theme] widget and [ThemeData].
///
/// [TomTheme] adds only what Flutter doesn't cover — how Tom's two
/// non-interactive authorization states look:
/// - **[readonlyStyle]** — the `read` state: visible, not editable.
/// - **[disabledStyle]** — the `disabled` state: visible, not available.
///   This is Tom's authorization `disabled`, not Material's `enabled: false`,
///   which is why it is themed here rather than left to [ThemeData].
///
/// [applyAuthState] is the single place that decides which of them a given
/// state gets, so the widget layer never spells the mapping out itself.
///
/// For semantic button style variants (primary, secondary, destructive,
/// auxiliary), use [TomButtonVariants]. It produces standard [ButtonStyle]
/// objects that you pass directly to the widget's `style` parameter.
///
/// Delivered to the widget tree via [TomThemeScope].
///
/// ## Example
///
/// ```dart
/// TomThemeScope(
///   theme: TomTheme(
///     readonlyStyle: TomStateStyle(opacity: 0.5),
///     disabledStyle: TomStateStyle(opacity: 0.2),
///   ),
///   child: MaterialApp(theme: themeData, home: MyApp()),
/// )
/// ```
class TomTheme {
  /// Treatment for `TomAuthState.read` — visible, but not editable.
  final TomStateStyle readonlyStyle;

  /// Treatment for `TomAuthState.disabled` — visible, but not available.
  final TomStateStyle disabledStyle;

  const TomTheme({
    this.readonlyStyle = TomStateStyle.readonly,
    this.disabledStyle = TomStateStyle.disabled,
  });

  /// A sensible default theme.
  static const defaultTheme = TomTheme();

  /// Creates a copy of this theme with the given overrides.
  TomTheme copyWith({
    TomStateStyle? readonlyStyle,
    TomStateStyle? disabledStyle,
  }) {
    return TomTheme(
      readonlyStyle: readonlyStyle ?? this.readonlyStyle,
      disabledStyle: disabledStyle ?? this.disabledStyle,
    );
  }

  /// Renders [content] under the treatment [state] calls for.
  ///
  /// The one place the four authorization states are mapped to appearance.
  /// Both enforcement points — `TomPolicyNodeBase` and
  /// `TomWidgetMixin.applyAuthState` — come through here, so the treatments
  /// cannot drift apart the way two hand-written switches did.
  ///
  /// [content] is a callback rather than a widget because `none` must not
  /// build what it is about to throw away: a hidden widget's content can be
  /// expensive, and it may not even be constructible under an authorization
  /// state that hides it.
  Widget applyAuthState(TomAuthState state, ValueGetter<Widget> content) {
    switch (state) {
      case TomAuthState.none:
        return const SizedBox.shrink();
      case TomAuthState.disabled:
        return disabledStyle.apply(content());
      case TomAuthState.read:
        return readonlyStyle.apply(content());
      case TomAuthState.full:
        return content();
    }
  }

  /// Compares by value, including the nested [readonlyStyle] and
  /// [disabledStyle].
  ///
  /// This is what makes [TomThemeScope.updateShouldNotify] meaningful. Both
  /// documented ways of installing a theme build it *inside* `build` — the
  /// example above, and `defaultTheme.copyWith(...)` — and `copyWith` always
  /// allocates, so the scope is handed a fresh instance on every ancestor
  /// rebuild. Under reference equality every one of those would count as a
  /// change and rebuild every read-only widget in the subtree; by value, only
  /// a theme whose fields actually moved does.
  ///
  /// [TomStateStyle.builder] is the single exception, compared by
  /// reference because closures cannot be compared any other way.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TomTheme &&
        other.runtimeType == runtimeType &&
        other.readonlyStyle == readonlyStyle &&
        other.disabledStyle == disabledStyle;
  }

  @override
  int get hashCode => Object.hash(readonlyStyle, disabledStyle);

  /// Whether this theme and [other] differ in their [TomStateStyle.builder]s
  /// and in nothing else.
  bool _differsOnlyInBuilders(TomTheme other) =>
      this != other &&
      readonlyStyle.equalsIgnoringBuilder(other.readonlyStyle) &&
      disabledStyle.equalsIgnoringBuilder(other.disabledStyle);
}

/// Provides a [TomTheme] to descendant widgets.
///
/// Place alongside (typically just inside) Flutter's [Theme] at the root
/// of your app, or in any subtree that needs a different Tom theme.
///
/// Widgets resolve Tom-specific theming via [TomThemeScope.of] or the
/// convenience accessor [readonlyStyleOf].
class TomThemeScope extends InheritedWidget {
  /// The theme for this scope.
  final TomTheme theme;

  const TomThemeScope({super.key, required this.theme, required super.child});

  /// Returns the nearest [TomTheme], or [TomTheme.defaultTheme] if none.
  static TomTheme of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TomThemeScope>();
    return scope?.theme ?? TomTheme.defaultTheme;
  }

  /// Returns the nearest `read` treatment, or [TomStateStyle.readonly].
  static TomStateStyle readonlyStyleOf(BuildContext context) {
    return of(context).readonlyStyle;
  }

  /// Returns the nearest `disabled` treatment, or [TomStateStyle.disabled].
  static TomStateStyle disabledStyleOf(BuildContext context) {
    return of(context).disabledStyle;
  }

  /// Renders [content] under the treatment [state] calls for, using the
  /// nearest theme.
  ///
  /// `TomThemeScope.of(context).applyAuthState(state, content)` in one call —
  /// the spelling the widget layer uses.
  static Widget applyAuthState(
    BuildContext context,
    TomAuthState state,
    ValueGetter<Widget> content,
  ) {
    return of(context).applyAuthState(state, content);
  }

  @override
  bool updateShouldNotify(TomThemeScope oldWidget) {
    final changed = theme != oldWidget.theme;
    assert(() {
      _watchForInlineBuilders(oldWidget.theme);
      return true;
    }());
    return changed;
  }

  /// How many updates in a row have changed nothing but a builder. Debug
  /// only: it is read and written inside an `assert`, so a release build
  /// carries neither the counter's effect nor the report.
  static int _builderOnlyChanges = 0;

  /// Whether the inline-builder report has been made. Once per process: a
  /// report per frame would bury the one line that matters.
  static bool _reportedInlineBuilder = false;

  /// Consecutive builder-only changes after which a builder is taken to be
  /// written inline. A deliberate switch between two named builders is one
  /// change, perhaps two; a closure literal in `build` is one per frame.
  static const int inlineBuilderThreshold = 3;

  /// Reports a [TomStateStyle.builder] that is allocated on every rebuild.
  ///
  /// A builder is compared by reference, so a closure literal written inside
  /// `build` makes every theme unequal to the last and rebuilds every
  /// read-only and disabled widget on every ancestor rebuild — a performance
  /// loss with no failure to point at it. The pattern is visible from here:
  /// the same scope keeps receiving themes that differ in their builders and
  /// in nothing else. After [inlineBuilderThreshold] such updates in a row, a
  /// non-fatal [FlutterError] names the cause and the fix.
  void _watchForInlineBuilders(TomTheme previous) {
    if (!theme._differsOnlyInBuilders(previous)) {
      _builderOnlyChanges = 0;
      return;
    }
    _builderOnlyChanges++;
    if (_builderOnlyChanges < inlineBuilderThreshold ||
        _reportedInlineBuilder) {
      return;
    }
    _reportedInlineBuilder = true;
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: FlutterError.fromParts([
          ErrorSummary(
            'A TomStateStyle.builder is allocated on every rebuild.',
          ),
          ErrorDescription(
            'TomThemeScope received $_builderOnlyChanges themes in a row that '
            'differ only in their builders. A builder is compared by '
            'reference, so a closure written inside build makes every theme '
            'new and rebuilds every read-only and disabled widget below this '
            'scope on every frame.',
          ),
          ErrorHint(
            'Hoist the builder into a top-level or static function, or hold '
            'it in a field, so the same function is passed each time.',
          ),
        ]),
        library: 'tom_flutter_ui theme',
      ),
    );
  }

  /// Clears the inline-builder detector's state. For tests only.
  @visibleForTesting
  static void debugResetInlineBuilderDetection() {
    _builderOnlyChanges = 0;
    _reportedInlineBuilder = false;
  }
}
