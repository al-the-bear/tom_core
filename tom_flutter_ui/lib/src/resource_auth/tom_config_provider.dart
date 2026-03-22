/// Global configuration provider for environment and platform behavior.
///
/// Configuration differs from resources: resources are user-facing text;
/// configuration is technical data (API endpoints, feature flags, platform
/// behavior) that varies by environment and platform.
class TomConfigProvider {
  static TomConfigProvider? _current;

  /// The current configuration instance.
  ///
  /// Throws if not initialized. Set during app startup.
  static TomConfigProvider get current {
    if (_current == null) {
      throw StateError('TomConfigProvider has not been initialized. '
          'Call TomConfigProvider.initialize() at app startup.');
    }
    return _current!;
  }

  /// Initializes the global configuration.
  static void initialize(TomConfigProvider config) => _current = config;

  /// Resets the configuration. Intended for testing only.
  static void reset() => _current = null;

  /// The current environment.
  final TomEnvironment environment;

  /// The current platform.
  final TomPlatform platform;

  final Map<String, Object> _flags;

  /// Creates a configuration with the given environment, platform, and flags.
  TomConfigProvider.create({
    required this.environment,
    required this.platform,
    Map<String, Object> flags = const {},
  }) : _flags = Map.unmodifiable(flags);

  /// Returns the value of a feature flag, or `null` if not set.
  T? feature<T>(String name) {
    final value = _flags[name];
    return value is T ? value : null;
  }

  /// Whether a feature flag is truthy.
  bool isEnabled(String name) {
    final value = _flags[name];
    return value == true || value == 'true' || value == 1;
  }
}

/// Application deployment environment.
enum TomEnvironment { development, staging, production }

/// Application target platform (logical, not physical).
enum TomPlatform { mobile, web, desktop }
