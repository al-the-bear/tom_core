import 'package:flutter/widgets.dart';

import 'tom_form_style_legacy.dart';

/// Provides a [TomFormStyleLegacy] to the widget tree via [InheritedWidget].
///
/// Nested scopes override parent scopes, enabling per-form or
/// per-section style customization.
///
/// ```dart
/// TomFormStyleScopeLegacy(
///   style: TomFormStyleLegacy(fieldSpacing: 20.0),
///   child: MyForm(),
/// )
/// ```
class TomFormStyleScopeLegacy extends InheritedWidget {
  /// The form style configuration for this scope.
  final TomFormStyleLegacy style;

  const TomFormStyleScopeLegacy({
    super.key,
    required this.style,
    required super.child,
  });

  /// Returns the nearest [TomFormStyleLegacy] in the widget tree,
  /// or [TomFormStyleLegacy.material3] if none is found.
  static TomFormStyleLegacy of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<TomFormStyleScopeLegacy>();
    return scope?.style ?? TomFormStyleLegacy.material3;
  }

  @override
  bool updateShouldNotify(TomFormStyleScopeLegacy oldWidget) =>
      style != oldWidget.style;
}
