/// Adapter that resolves user-facing text resources by base path and suffix.
///
/// Resources are locale-aware and process-context-aware. The correct resource
/// set is resolved during app initialization — widgets simply look up keys.
abstract class TomUIResourceAdapter {
  /// Resolves a text resource for [basePath] with [suffix].
  ///
  /// Returns the resolved string, or the full key as a fallback indicator
  /// if no resource is found.
  String resolveText(String basePath, String suffix);

  /// Whether a resource exists for [basePath] with [suffix].
  bool resourceExists(String basePath, String suffix);
}

/// Global text resource singleton.
///
/// Initialized at app startup with a concrete adapter. Widgets resolve
/// labels, hints, error messages, and tooltips through this — no
/// [InheritedWidget] or [BuildContext] needed.
///
/// ```dart
/// // App startup
/// TomUIResources.adapter = TomKernelResourceAdapter();
///
/// // Usage anywhere
/// final label = TomUIResources.resolveText('r-checkout.w-email', 'label');
/// ```
class TomUIResources {
  TomUIResources._();

  static TomUIResourceAdapter? _adapter;

  static set adapter(TomUIResourceAdapter adapter) => _adapter = adapter;

  /// Resolves the text resource for [basePath] + [suffix].
  ///
  /// If no adapter is set, returns the full key (`basePath.suffix`) as a
  /// visible indicator that a resource is missing.
  static String resolveText(String basePath, String suffix) {
    return _adapter?.resolveText(basePath, suffix) ?? '$basePath.$suffix';
  }

  /// Whether a resource exists for [basePath] + [suffix].
  static bool resourceExists(String basePath, String suffix) {
    return _adapter?.resourceExists(basePath, suffix) ?? false;
  }

  /// Resets the adapter. Intended for testing only.
  static void reset() => _adapter = null;
}
