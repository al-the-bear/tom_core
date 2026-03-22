import 'package:flutter/material.dart';

import 'tom_readonly_style.dart';
import 'tom_style_variant.dart';
import 'tom_variant_map.dart';

/// Tom-specific theme extensions that layer on top of Flutter's [ThemeData].
///
/// Tom does **not** replace Flutter's theming. Colors, typography, shapes,
/// elevation, disabled styling, dark/light mode, and per-widget theme data
/// are all handled by Flutter's [Theme] widget and [ThemeData].
///
/// [TomTheme] adds only what Flutter doesn't cover:
/// - **[readonlyStyle]** — configurable visual treatment for authorization-
///   readonly widgets (a Tom authorization concept, not a Material concept).
/// - **[variantMap]** — maps semantic [TomStyleVariant] roles (primary,
///   secondary, destructive, auxiliary) to concrete Flutter
///   [ButtonStyle]/[InputDecoration]/[ChipThemeData] values.
///
/// Delivered to the widget tree via [TomThemeScope].
///
/// ## Example
///
/// ```dart
/// TomThemeScope(
///   theme: TomTheme(
///     readonlyStyle: TomReadonlyStyle(opacity: 0.5),
///     variantMap: TomVariantMap(
///       buttonVariants: {
///         TomStyleVariant.primary: ElevatedButton.styleFrom(
///           backgroundColor: colorScheme.primary,
///         ),
///       },
///     ),
///   ),
///   child: MaterialApp(theme: themeData, home: MyApp()),
/// )
/// ```
class TomTheme {
  /// Human-readable name for this theme.
  final String name;

  /// Global readonly style applied when no per-family override exists.
  final TomReadonlyStyle readonlyStyle;

  /// Maps semantic [TomStyleVariant] values to concrete Flutter styles.
  final TomVariantMap variantMap;

  const TomTheme({
    this.name = 'default',
    this.readonlyStyle = const TomReadonlyStyle(),
    this.variantMap = const TomVariantMap(),
  });

  /// A sensible default theme.
  static const defaultTheme = TomTheme();

  /// Creates a copy of this theme with the given overrides.
  TomTheme copyWith({
    String? name,
    TomReadonlyStyle? readonlyStyle,
    TomVariantMap? variantMap,
  }) {
    return TomTheme(
      name: name ?? this.name,
      readonlyStyle: readonlyStyle ?? this.readonlyStyle,
      variantMap: variantMap ?? this.variantMap,
    );
  }
}

/// Provides a [TomTheme] to descendant widgets.
///
/// Place alongside (typically just inside) Flutter's [Theme] at the root
/// of your app, or in any subtree that needs a different Tom theme.
///
/// Widgets resolve Tom-specific theming via [TomThemeScope.of] or the
/// convenience accessors like [readonlyStyleOf] and [buttonStyleFor].
///
/// ## Example — full app setup
///
/// ```dart
/// TomThemeScope(
///   theme: TomTheme(
///     readonlyStyle: TomReadonlyStyle(opacity: 0.5),
///     variantMap: TomVariantMap(
///       buttonVariants: {
///         TomStyleVariant.primary: ElevatedButton.styleFrom(
///           backgroundColor: themeData.colorScheme.primary,
///           foregroundColor: themeData.colorScheme.onPrimary,
///         ),
///         TomStyleVariant.destructive: ElevatedButton.styleFrom(
///           backgroundColor: themeData.colorScheme.error,
///           foregroundColor: themeData.colorScheme.onError,
///         ),
///       },
///     ),
///   ),
///   child: MaterialApp(theme: themeData, home: MyHomePage()),
/// )
/// ```
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

  /// Returns the [ButtonStyle] for the given [variant], or `null` if not mapped.
  static ButtonStyle? buttonStyleFor(
      BuildContext context, TomStyleVariant? variant) {
    if (variant == null) return null;
    return of(context).variantMap.buttonStyleFor(variant);
  }

  /// Returns the [InputDecoration] for the given [variant], or `null`.
  static InputDecoration? inputDecorationFor(
      BuildContext context, TomStyleVariant? variant) {
    if (variant == null) return null;
    return of(context).variantMap.inputDecorationFor(variant);
  }

  /// Returns the [ChipThemeData] for the given [variant], or `null`.
  static ChipThemeData? chipThemeFor(
      BuildContext context, TomStyleVariant? variant) {
    if (variant == null) return null;
    return of(context).variantMap.chipThemeFor(variant);
  }

  @override
  bool updateShouldNotify(TomThemeScope oldWidget) {
    return theme != oldWidget.theme;
  }
}
