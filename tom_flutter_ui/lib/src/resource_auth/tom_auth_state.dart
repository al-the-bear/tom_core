import 'package:flutter/widgets.dart';

/// The two authorization outcomes for a UI element: visibility and readonly.
///
/// "Disabled" is NOT an authorization state — disabling is business logic.
/// Authorization controls access; business logic controls behavior.
class TomAuthState {
  final bool visible;
  final bool readonly;

  const TomAuthState({required this.visible, this.readonly = false});

  static const fullAccess = TomAuthState(visible: true);
  static const hidden = TomAuthState(visible: false);
  static const readOnly = TomAuthState(visible: true, readonly: true);
}

/// Adapter that resolves authorization state for a given resource key path.
///
/// Implementations bridge the kernel security layer to the UI:
/// - [TomKernelAuthorizationAdapter] uses the kernel's resource key protection.
/// - Test implementations can return predetermined results.
abstract class TomUIAuthorizationAdapter {
  TomAuthState resolveAuth(String resourceKeyPath);
}

/// Global authorization singleton.
///
/// Initialized at app startup with a concrete adapter. Widgets, forms, and
/// actions access it directly — no [InheritedWidget] or [BuildContext] needed.
///
/// ```dart
/// // App startup
/// TomUIAuthorization.adapter = TomKernelAuthorizationAdapter();
///
/// // Usage anywhere
/// final auth = TomUIAuthorization.resolveAuth('r-checkout.w-email');
/// ```
class TomUIAuthorization {
  TomUIAuthorization._();

  static TomUIAuthorizationAdapter? _adapter;

  static set adapter(TomUIAuthorizationAdapter adapter) => _adapter = adapter;

  /// Resolves authorization for the given resource key path.
  ///
  /// Returns [TomAuthState.fullAccess] if no adapter is set (development mode).
  static TomAuthState resolveAuth(String resourceKeyPath) {
    return _adapter?.resolveAuth(resourceKeyPath) ?? TomAuthState.fullAccess;
  }

  /// Resets the adapter. Intended for testing only.
  @visibleForTesting
  static void reset() => _adapter = null;
}
