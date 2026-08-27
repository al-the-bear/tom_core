/// Inline wrapper that hides or disables its [TomAuthGuard.child] based
/// on the authorization state resolved from a `tomId` (resource key
/// path).
///
/// Reach for it wherever a subtree's visibility follows a resource key,
/// in place of calling `TomAuthorization.resolveAuth(...)` at the call
/// site and branching by hand.
///
/// The guard supports four [TomAuthState] outcomes:
/// * `none` — child is removed from the tree (replaced by
///   [TomAuthGuard.hiddenBuilder] or `SizedBox.shrink()`).
/// * `disabled` — child is rendered behind an [IgnorePointer] and faded
///   to [TomAuthGuard.disabledOpacity].
/// * `read` — child is rendered behind an [IgnorePointer] (interactive
///   elements are blocked but content is fully visible).
/// * `full` — child is rendered as-is.
///
/// Re-evaluates the auth state on every build, so the guarded subtree
/// flips automatically when the active [TomAuthorizationAdapter] does.
library;

import 'package:flutter/widgets.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../widget_base/tom_scope_path.dart';

/// Inline wrapper that hides or disables its [child] based on the
/// resolved [TomAuthState] for the given [tomId] (resource key path).
class TomAuthGuard extends StatelessWidget {
  /// Resource key path to resolve authorization for. The path is passed
  /// straight to [TomAuthorization.resolveAuth] — callers can use a
  /// fully qualified path or rely on the active [TomScope] by passing
  /// only the leaf id.
  final String tomId;

  /// Optional explicit scope override. When `null`, the guard uses
  /// [TomScope.current] to qualify [tomId].
  final TomScope? scope;

  /// Subtree to guard. Rendered when the resolved auth allows it.
  final Widget child;

  /// Optional builder invoked when the auth state is [TomAuthState.none].
  /// When `null`, the guarded subtree collapses to [SizedBox.shrink].
  final WidgetBuilder? hiddenBuilder;

  /// Opacity applied to the child when auth is [TomAuthState.disabled].
  /// Defaults to `0.4`.
  final double disabledOpacity;

  /// Whether [TomAuthState.read] should also block interaction (default
  /// `true`). Some call-sites prefer to leave the child fully
  /// interactive in read-only mode and let the wrapped widget itself
  /// react — set this to `false` to opt out of pointer blocking.
  final bool blockPointerOnRead;

  const TomAuthGuard({
    super.key,
    required this.tomId,
    required this.child,
    this.scope,
    this.hiddenBuilder,
    this.disabledOpacity = 0.4,
    this.blockPointerOnRead = true,
  });

  /// Resolves the guarded auth state through [TomAuthorization].
  ///
  /// Public and `@visibleForTesting` so the decision can be asserted on a
  /// constructed guard without pumping a widget — which is what
  /// `custom_example_test.dart` does, once per state. The annotation is
  /// the tell: were the point to let tests *replace* the resolution by
  /// subclassing, this would be `@visibleForOverriding`.
  @visibleForTesting
  TomAuthState resolveAuthState() =>
      TomAuthorization.resolveAuth(TomScopePath.qualify(tomId, scope));

  @override
  Widget build(BuildContext context) {
    final state = resolveAuthState();
    switch (state) {
      case TomAuthState.none:
        return hiddenBuilder?.call(context) ?? const SizedBox.shrink();
      case TomAuthState.disabled:
        return IgnorePointer(
          child: Opacity(opacity: disabledOpacity, child: child),
        );
      case TomAuthState.read:
        return blockPointerOnRead ? IgnorePointer(child: child) : child;
      case TomAuthState.full:
        return child;
    }
  }
}
