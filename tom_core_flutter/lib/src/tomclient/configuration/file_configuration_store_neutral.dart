import 'client_configuration_store.dart';

/// The stand-in for [TomFileClientConfigurationStore] on targets without a
/// filesystem — in practice, the web.
///
/// It **throws on construction** with
/// `client_configuration.store.unsupported_platform` rather than silently
/// degrading to an in-memory store. A settings screen whose Save button
/// appears to work but forgets everything on reload is a worse outcome than a
/// failure at startup, and only the app knows what the browser equivalent
/// should be (`window.localStorage`, IndexedDB, a server round-trip) — so the
/// choice belongs to the app, made explicitly, not to a fallback made here.
///
/// A client that genuinely wants no machine-local persistence should say so by
/// using [TomMemoryClientConfigurationStore].
class TomFileClientConfigurationStore extends TomClientConfigurationStore {
  /// Always throws — see the class documentation.
  TomFileClientConfigurationStore(this.path) {
    throw TomClientConfigurationException(
      'client_configuration.store.unsupported_platform',
      'A file-backed client configuration store needs a filesystem, which is '
          'not available on this platform. Supply a platform-appropriate '
          'TomClientConfigurationStore instead.',
      parameters: {'path': path},
    );
  }

  /// The path that was requested. Retained only so the failure can name it.
  final String path;

  @override
  Future<Map<String, Object?>> read() async => {};

  @override
  Future<Map<String, Object?>> update(
    Map<String, Object?> Function(Map<String, Object?> current) change,
  ) async => {};
}
