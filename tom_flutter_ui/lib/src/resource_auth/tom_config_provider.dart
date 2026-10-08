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
      throw StateError(
        'TomConfigProvider has not been initialized. '
        'Call TomConfigProvider.initialize() at app startup.',
      );
    }
    return _current!;
  }

  /// Initializes the global configuration.
  static void initialize(TomConfigProvider config) => _current = config;

  /// Resets the configuration. Intended for testing only.
  static void reset() => _current = null;

  /// The current environment.
  final TomConfigEnvironment environment;

  /// The current platform.
  final TomConfigPlatform platform;

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

  /// Whether the feature flag [name] is enabled.
  ///
  /// A flag is enabled when it is the boolean `true`, a number equal to `1`
  /// (so `1.0` counts), or a string reading `true` or `1` once case and
  /// surrounding whitespace are folded away. Everything else is disabled:
  /// `false`, `0`, `'false'`, a value outside that vocabulary (`'yes'`, `2`),
  /// a value of some other type, and a flag that was never set.
  ///
  /// The tolerance exists because a flag arrives spelled differently
  /// depending on where it was authored — Dart hands over a `bool`, YAML and
  /// JSON a `bool` or a `num`, and `--dart-define` and environment variables
  /// can only carry text. Which source a flag came through must not change
  /// what it means.
  ///
  /// It stops at spelling. Synonyms — `'yes'`, `'on'`, `'y'` — are *not*
  /// enabled, because admitting one commits this to a list of them that
  /// nobody agreed on. It is the line [TomAllColorsAdapter] already draws: it
  /// folds case in `#FFF` and `rgb(...)` syntax and still does not know what
  /// `crimson` means.
  ///
  /// Being outside the vocabulary is not the same as being lost — [feature]
  /// still reports the value unchanged, which is where anything richer than
  /// on/off belongs.
  bool isEnabled(String name) {
    final value = _flags[name];
    if (value is bool) return value;
    if (value is num) return value == 1;
    if (value is String) {
      final text = value.trim().toLowerCase();
      return text == 'true' || text == '1';
    }
    return false;
  }
}

/// Application deployment environment.
enum TomConfigEnvironment { development, staging, production }

/// Application target platform (logical, not physical).
enum TomConfigPlatform { mobile, web, desktop }
