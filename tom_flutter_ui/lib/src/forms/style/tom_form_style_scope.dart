import 'package:flutter/widgets.dart';

import 'tom_form_style.dart';

/// Provides a [TomFormStyle] to the widget tree via [InheritedWidget].
///
/// Nested scopes override parent scopes, enabling per-form or
/// per-section style customization.
///
/// ```dart
/// TomFormStyleScope(
///   style: TomFormStyle(fieldSpacing: 20.0),
///   child: MyForm(),
/// )
/// ```
class TomFormStyleScope extends InheritedWidget {
  /// The form style configuration for this scope.
  final TomFormStyle style;

  const TomFormStyleScope({
    super.key,
    required this.style,
    required super.child,
  });

  /// Returns the nearest [TomFormStyle] in the widget tree,
  /// or [TomFormStyle.material3] if none is found.
  static TomFormStyle of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<TomFormStyleScope>();
    return scope?.style ?? TomFormStyle.material3;
  }

  @override
  bool updateShouldNotify(TomFormStyleScope oldWidget) =>
      style != oldWidget.style;
}
