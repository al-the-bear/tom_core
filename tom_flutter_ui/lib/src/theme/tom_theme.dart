import 'package:flutter/widgets.dart';

import 'tom_readonly_style.dart';

/// Top-level theme definition for the Tom UI framework.
///
/// Aggregates per-family style definitions, readonly visual treatment,
/// and color configuration. Delivered to the widget tree via
/// [TomThemeScope].
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
/// Place at the root of your app (or any subtree that needs a different
/// theme). Widgets resolve theming via [TomThemeScope.of] or the
/// convenience accessors like [readonlyStyleOf].
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
