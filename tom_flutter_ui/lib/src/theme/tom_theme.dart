import 'package:flutter/widgets.dart';

import 'tom_readonly_style.dart';

/// Tom-specific theme extensions that layer on top of Flutter's [ThemeData].
///
/// Tom does **not** replace Flutter's theming. Colors, typography, shapes,
/// elevation, disabled styling, dark/light mode, and per-widget theme data
/// are all handled by Flutter's [Theme] widget and [ThemeData].
///
/// [TomTheme] adds only what Flutter doesn't cover:
/// - **[readonlyStyle]** — configurable visual treatment for authorization-
///   readonly widgets (a Tom authorization concept, not a Material concept).
///
/// For semantic style variants (primary, secondary, destructive, auxiliary),
/// use the helper factories in [TomButtonVariants], [TomInputVariants], and
/// [TomChipVariants]. These produce standard Flutter style objects that you
/// pass directly to the widget's `style` / `decoration` parameter.
///
/// Delivered to the widget tree via [TomThemeScope].
///
/// ## Example
///
/// ```dart
/// TomThemeScope(
///   theme: TomTheme(
///     readonlyStyle: TomReadonlyStyle(opacity: 0.5),
///   ),
///   child: MaterialApp(theme: themeData, home: MyApp()),
/// )
/// ```
class TomTheme {
  /// Human-readable name for this theme.
  final String name;

  /// Global readonly style applied when no per-family override exists.
  final TomReadonlyStyle readonlyStyle;

  const TomTheme({
    this.name = 'default',
    this.readonlyStyle = const TomReadonlyStyle(),
  });

  /// A sensible default theme.
  static const defaultTheme = TomTheme();

  /// Creates a copy of this theme with the given overrides.
  TomTheme copyWith({
    String? name,
    TomReadonlyStyle? readonlyStyle,
  }) {
    return TomTheme(
      name: name ?? this.name,
      readonlyStyle: readonlyStyle ?? this.readonlyStyle,
    );
  }
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

  const TomThemeScope({
    super.key,
    required this.theme,
    required super.child,
  });

  /// Returns the nearest [TomTheme], or [TomTheme.defaultTheme] if none.
  static TomTheme of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TomThemeScope>();
    return scope?.theme ?? TomTheme.defaultTheme;
  }

  /// Returns the nearest [TomReadonlyStyle], or [TomReadonlyStyle.defaultStyle].
  static TomReadonlyStyle readonlyStyleOf(BuildContext context) {
    return of(context).readonlyStyle;
  }

  @override
  bool updateShouldNotify(TomThemeScope oldWidget) {
    return theme != oldWidget.theme;
  }
}
