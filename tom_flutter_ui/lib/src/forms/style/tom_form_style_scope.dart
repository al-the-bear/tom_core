library;

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../widget_base/tom_construction_helpers.dart';
import 'tom_form_style.dart';

/// Provides a [TomFormStyle] plus the current available width to descendant
/// fields via an `InheritedWidget`, so decoration mixins can resolve
/// breakpointed properties without querying any surrounding layout widget.
///
/// The scope wraps its [child] in a [LayoutBuilder] and publishes the
/// constraints' `maxWidth` through [widthOf]. When no scope is found in the
/// ancestor chain, fields fall back to [TomFormStyle.material3] and to
/// `MediaQuery.sizeOf(context).width`.
///
/// Resource overlay is opt-in: it runs only when [tomId] is set. The
/// resolved namespace is `TomCtr.resolvePath(tomId, scope)` — either the
/// supplied [scope] or the ambient one. For Phase 2 the overlay is a
/// no-op stub; the canonical keys land with the decoration-mixin cut-over
/// in Phase 3.
class TomFormStyleScope extends StatelessWidget {
  /// Optional Tom identifier. When non-null, the scope reads property
  /// overrides from resources rooted at
  /// `TomCtr.resolvePath(tomId, scope)`.
  final String? tomId;

  /// Optional explicit [TomScope] to override the ambient one. When null,
  /// [TomScope.current] is used.
  final TomScope? scope;

  /// The programmatic base style. Resources (when [tomId] is set) only
  /// override individual named properties on top of this.
  final TomFormStyle style;

  final Widget child;

  const TomFormStyleScope({
    super.key,
    this.tomId,
    this.scope,
    required this.style,
    required this.child,
  });

  /// Returns the nearest scope's resolved style, or [TomFormStyle.material3]
  /// when no scope is found.
  static TomFormStyle of(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<_TomFormStyleInheritedScope>();
    return inherited?.style ?? TomFormStyle.material3;
  }

  /// Returns the width captured by the nearest enclosing
  /// [TomFormStyleScope]. When no scope is found, falls back to
  /// `MediaQuery.sizeOf(context).width`.
  static double widthOf(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<_TomFormStyleInheritedScope>();
    if (inherited != null) return inherited.width;
    return MediaQuery.sizeOf(context).width;
  }

  @override
  Widget build(BuildContext context) {
    final resolvedPath = TomCtr.resolvePath(tomId, scope);
    // Overlay is a no-op stub in Phase 2; individual property keys are
    // wired in Phase 3 alongside the decoration-mixin cut-over.
    final resolvedStyle =
        resolvedPath == null ? style : _applyResourceOverlay(style, resolvedPath);

    return LayoutBuilder(
      builder: (context, constraints) {
        return _TomFormStyleInheritedScope(
          style: resolvedStyle,
          width: constraints.maxWidth,
          child: child,
        );
      },
    );
  }

  /// Resource overlay hook. Phase 2 ships a passthrough; Phase 3 replaces
  /// this with the keyed resolver that reads individual property keys via
  /// [TomCtr.textStyle], [TomCtr.inputBorder], [TomCtr.widgetStateColor],
  /// and [TomCtr.breakpointed].
  TomFormStyle _applyResourceOverlay(TomFormStyle base, String _) => base;
}

class _TomFormStyleInheritedScope extends InheritedWidget {
  final TomFormStyle style;
  final double width;

  const _TomFormStyleInheritedScope({
    required this.style,
    required this.width,
    required super.child,
  });

  @override
  bool updateShouldNotify(_TomFormStyleInheritedScope oldWidget) =>
      style != oldWidget.style || width != oldWidget.width;
}
