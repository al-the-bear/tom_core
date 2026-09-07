import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A [MaterialPageRoute] that propagates the active [TomScope] across
/// navigation.
///
/// Flutter builds a route's child lazily — inside the [Navigator]'s build, not
/// at the push site — so a screen pushed with a raw [MaterialPageRoute]
/// captures whatever [TomScope] is current *there* (normally
/// [TomScope.defaultScope]), silently dropping the scope that was active when
/// the push happened. The scope-aware widget bases
/// ([TomStatelessWidget]/[TomState], see `tom_scope_widgets.dart`) capture
/// [TomScope.current] at construction, so that hole means a pushed screen would
/// resolve its resources and identity against the wrong scope.
///
/// [TomPageRoute] captures [TomScope.current] at construction (push time) and
/// re-enters it around [builder] via [ScopeCapture] — the same mechanism the
/// Tom widgets use to carry scope through callbacks — so the pushed screen is
/// constructed in the pushing scope. This closes the propagation gap and gives
/// navigation the same scope guarantee the widget bases give. Pass [scope] to
/// override the captured scope explicitly.
///
/// ```dart
/// Navigator.of(context).push(
///   TomPageRoute<bool>(builder: (_) => DetailScreen(item: item)),
/// );
/// ```
class TomPageRoute<T> extends MaterialPageRoute<T> {
  /// Creates a scope-propagating page route.
  ///
  /// [builder] is wrapped so the pushed screen constructs in [scope] (or, when
  /// omitted, the [TomScope.current] captured at push time).
  TomPageRoute({
    required WidgetBuilder builder,
    TomScope? scope,
    super.settings,
    super.maintainState,
    super.fullscreenDialog,
    super.allowSnapshotting,
    super.barrierDismissible,
  }) : super(builder: ScopeCapture(scope: scope).wrap1(builder));
}
