/// Resource providers for managing application text resources and configuration.
///
/// This library provides singleton-based resource management for:
/// - **Text resources**: Localized strings, UI labels, and messages
/// - **Configuration resources**: Application settings and environment configuration
///
/// Both providers support hierarchical key access using dot notation (e.g., 'app.title')
/// and can be initialized from JSON maps or loader functions.
///
/// ## Example
///
/// ```dart
/// // Set up a text resource provider
/// TomTextResourceProvider.loader = () => {
///   'app': {'title': 'My App', 'version': '1.0.0'},
///   'messages': {'welcome': 'Hello, World!'}
/// };
///
/// // Access resources anywhere in the app
/// final resources = TomTextResourceProvider.getAppResources();
/// print(resources.getText('app.title')); // 'My App'
/// print(resources.getText('messages.welcome')); // 'Hello, World!'
/// ```
library;

// =============================================================================
// Imports
// =============================================================================

import '../json/map_merge_and_process.dart';

// =============================================================================
// Text Resource Provider
// =============================================================================

/// A singleton provider for managing text resources in the application.
///
/// [TomTextResourceProvider] is designed for storing and retrieving text-based
/// resources such as localized strings, UI labels, error messages, and other
/// text content that may vary by locale or configuration. It also supports
/// retrieval of object values using the existsObject and getObject methods,
/// this is intended for extended UI configuration which is related to look
/// and feel of the UI, such as TextStyles, Colors, etc. This allows for a unified resource management
///
/// The provider supports:
/// - Singleton access via [getAppResources]
/// - Hierarchical key access using dot notation
/// - Lazy initialization with a loader function
/// - Direct initialization from a map
///
/// ## Usage
///
/// ### Setting up with a loader function
///
/// ```dart
/// // Define the loader before first access
/// TomTextResourceProvider.loader = () => loadJsonFromAssets('strings.json');
///
/// // Access resources throughout the app
/// final resources = TomTextResourceProvider.getAppResources();
/// String title = resources.getText('screens.home.title');
/// ```
///
/// ### Setting up with a custom provider
///
/// ```dart
/// final customProvider = TomTextResourceProvider.from({
///   'greeting': 'Hello',
///   'farewell': 'Goodbye',
/// });
/// TomTextResourceProvider.setAppResourceProvider(customProvider);
/// ```
///
/// ### Checking resource existence
///
/// ```dart
/// if (resources.exists('optional.message')) {
///   showMessage(resources.getText('optional.message'));
/// }
/// ```
class TomTextResourceProvider {
  // ---------------------------------------------------------------------------
  // Static Fields
  // ---------------------------------------------------------------------------

  /// The singleton instance of the text resource provider.
  static TomTextResourceProvider? _resourceProvider;

  /// Optional loader function to initialize resources lazily.
  ///
  /// Set this before the first call to [getAppResources] to provide
  /// a custom resource loading mechanism (e.g., loading from JSON assets).
  static Map<String, dynamic> Function()? loader;

  // ---------------------------------------------------------------------------
  // Static Methods
  // ---------------------------------------------------------------------------

  /// Sets the application-wide text resource provider instance.
  ///
  /// Use this method to replace the default provider with a custom
  /// pre-configured instance.
  ///
  /// [provider] - The provider instance to use application-wide.
  static void setAppResourceProvider(TomTextResourceProvider provider) {
    _resourceProvider = provider;
  }

  /// Returns the application-wide text resource provider.
  ///
  /// If no provider has been set, creates a new instance using the
  /// [loader] function if available, or an empty provider otherwise.
  ///
  /// This method implements lazy initialization - the provider is created
  /// on first access.
  static TomTextResourceProvider getAppResources() {
    _resourceProvider ??= TomTextResourceProvider();
    return _resourceProvider!;
  }

  // ---------------------------------------------------------------------------
  // Instance Fields
  // ---------------------------------------------------------------------------

  /// The map containing all text resources.
  ///
  /// Resources can be nested maps, with values accessed using dot notation.
  Map<String, dynamic> resources = {};

  // ---------------------------------------------------------------------------
  // Constructors
  // ---------------------------------------------------------------------------

  /// Creates a new text resource provider.
  ///
  /// If [loader] is set, it will be called to initialize the resources.
  /// Otherwise, an empty resource map is created.
  TomTextResourceProvider() {
    if (loader != null) {
      resources = loader!();
    }
  }

  /// Creates a new text resource provider with a custom loader function.
  ///
  /// [loader] - A function that returns the resource map.
  TomTextResourceProvider.load(Map<String, dynamic> Function() loader) {
    resources = loader();
  }

  /// Creates a new text resource provider from an existing map.
  ///
  /// [resources] - The pre-populated resource map.
  TomTextResourceProvider.from(this.resources);

  // ---------------------------------------------------------------------------
  // Instance Methods
  // ---------------------------------------------------------------------------

  /// Checks if a text resource exists at the given path.
  ///
  /// Supports both flat keys (e.g., 'title') and hierarchical paths
  /// using dot notation (e.g., 'screens.home.title').
  ///
  /// [s] - The resource key or path to check.
  ///
  /// Returns `true` if a String value exists at the path, `false` otherwise.
  bool exists(String s) {
    try {
      dynamic value = getObjectFromTree(resources, s);
      if (value is String) return true;
    } catch (ex) {
      // fall through
    }
    return resources[s] != null && resources[s] is String;
  }

  /// Checks if an object resource exists at the given path.
  ///
  /// Unlike [exists], this accepts any resource type (TextStyles, Colors, and
  /// other non-String UI values), not only String text resources.
  ///
  /// Supports both flat keys (e.g., 'title') and hierarchical paths
  /// using dot notation (e.g., 'screens.home.style').
  ///
  /// [s] - The resource key or path to check.
  ///
  /// Returns `true` if any value exists at the path, `false` otherwise.
  bool existsObject(String s) {
    try {
      getObjectFromTree(resources, s);
      return true;
    } catch (ex) {
      // fall through
    }
    return resources[s] != null;
  }

  /// Retrieves the object resource at the given path.
  ///
  /// Returns non-String UI values (TextStyles, Colors, etc.) as well as text;
  /// use [getText] when a String is required.
  ///
  /// Supports both flat keys (e.g., 'title') and hierarchical paths
  /// using dot notation (e.g., 'screens.home.style').
  ///
  /// If the resource is not found, returns the key itself as a fallback,
  /// which helps identify missing resources during development.
  ///
  /// [s] - The resource key or path to retrieve.
  ///
  /// Returns the value if found (can be any type), or the key [s] if not found.
  Object getObject(String s) {
    try {
      dynamic value = getObjectFromTree(resources, s);
      return value;
    } catch (ex) {
      // fall through
    }
    return resources[s] != null ? resources[s]! : s;
  }

  /// Retrieves the object resource at the given path.
  ///
  /// Returns non-String UI values (TextStyles, Colors, etc.) as well as text;
  /// use [getTextOrNull] when a String is required.
  ///
  /// Supports both flat keys (e.g., 'title') and hierarchical paths
  /// using dot notation (e.g., 'screens.home.style').
  ///
  /// If the resource is not found, returns null as a fallback,
  /// which helps identify missing resources during development.
  ///
  /// [s] - The resource key or path to retrieve.
  ///
  /// Returns the value if found (can be any type), or null if not found.
  Object? getObjectOrNull(String s) {
    try {
      dynamic value = getObjectFromTree(resources, s);
      return value;
    } catch (ex) {
      // fall through
    }
    return resources[s] != null ? resources[s]! : null;
  }

  /// Retrieves the text value at the given path.
  ///
  /// Supports both flat keys (e.g., 'title') and hierarchical paths
  /// using dot notation (e.g., 'screens.home.title').
  ///
  /// If the resource is not found, returns the key itself as a fallback,
  /// which helps identify missing resources during development.
  ///
  /// [s] - The resource key or path to retrieve.
  ///
  /// Returns the text value if found, or the key [s] if not found.
  String getText(String s) {
    try {
      dynamic value = getObjectFromTree(resources, s);
      if (value is String) return value;
    } catch (ex) {
      // fall through
    }
    return (resources[s] != null && resources[s] is String)
        ? resources[s]! as String
        : s;
  }

  /// Retrieves the text value at the given path.
  ///
  /// Supports both flat keys (e.g., 'title') and hierarchical paths
  /// using dot notation (e.g., 'screens.home.title').
  ///
  /// If the resource is not found, returns null as a fallback,
  /// which helps identify missing resources during development.
  ///
  /// [s] - The resource key or path to retrieve.
  ///
  /// Returns the text value if found, or null if not found.
  String? getTextOrNull(String s) {
    try {
      dynamic value = getObjectFromTree(resources, s);
      if (value is String) return value;
    } catch (ex) {
      // fall through
    }
    return (resources[s] != null && resources[s] is String)
        ? resources[s]! as String
        : null;
  }
}

// =============================================================================
// Configuration Resource Provider
// =============================================================================

/// A singleton provider for managing configuration resources in the application.
///
/// [TomConfigResourceProvider] is designed for storing and retrieving
/// configuration values such as API endpoints, feature flags, timeouts,
/// and other application settings.
///
/// ## Usage
///
/// ### Setting up with a loader function
///
/// ```dart
/// // Define the loader before first access
/// TomConfigResourceProvider.loader = () => loadJsonFromAssets('config.json');
///
/// // Access configuration throughout the app
/// final config = TomConfigResourceProvider.getAppConfig();
/// String apiUrl = config.getText('api.baseUrl') as String;
/// int timeout = config.getText('api.timeout') as int;
/// ```
///
/// ### Setting up with a custom provider
///
/// ```dart
/// final customConfig = TomConfigResourceProvider.from({
///   'api': {
///     'baseUrl': 'https://api.example.com',
///     'timeout': 30000,
///   },
///   'features': {
///     'darkMode': true,
///     'analytics': false,
///   },
/// });
/// TomConfigResourceProvider.setAppConfigProvider(customConfig);
/// ```
///
/// ### Checking configuration existence
///
/// ```dart
/// if (config.exists('features.experimental')) {
///   enableExperimentalFeatures();
/// }
/// ```
class TomConfigResourceProvider {
  // ---------------------------------------------------------------------------
  // Static Fields
  // ---------------------------------------------------------------------------

  /// The singleton instance of the configuration provider.
  static TomConfigResourceProvider? _configProvider;

  /// Optional loader function to initialize configuration lazily.
  ///
  /// Set this before the first call to [getAppConfig] to provide
  /// a custom configuration loading mechanism (e.g., loading from JSON assets).
  static Map<String, dynamic> Function()? loader;

  // ---------------------------------------------------------------------------
  // Static Methods
  // ---------------------------------------------------------------------------

  /// Sets the application-wide configuration provider instance.
  ///
  /// Use this method to replace the default provider with a custom
  /// pre-configured instance.
  ///
  /// [provider] - The provider instance to use application-wide.
  static void setAppConfigProvider(TomConfigResourceProvider provider) {
    _configProvider = provider;
  }

  /// Returns the application-wide configuration provider.
  ///
  /// If no provider has been set, creates a new instance using the
  /// [loader] function if available, or an empty provider otherwise.
  ///
  /// This method implements lazy initialization - the provider is created
  /// on first access.
  static TomConfigResourceProvider getAppConfig() {
    _configProvider ??= TomConfigResourceProvider();
    return _configProvider!;
  }

  // ---------------------------------------------------------------------------
  // Instance Fields
  // ---------------------------------------------------------------------------

  /// The map containing all configuration values.
  ///
  /// Configuration can be nested maps, with values accessed using dot notation.
  Map<String, dynamic> resources = {};

  // ---------------------------------------------------------------------------
  // Constructors
  // ---------------------------------------------------------------------------

  /// Creates a new configuration provider.
  ///
  /// If [loader] is set, it will be called to initialize the configuration.
  /// Otherwise, an empty configuration map is created.
  TomConfigResourceProvider() {
    if (loader != null) {
      resources = loader!();
    }
  }

  /// Creates a new configuration provider with a custom loader function.
  ///
  /// [loader] - A function that returns the configuration map.
  TomConfigResourceProvider.load(Map<String, dynamic> Function() loader) {
    resources = loader();
  }

  /// Creates a new configuration provider from an existing map.
  ///
  /// [resources] - The pre-populated configuration map.
  TomConfigResourceProvider.from(this.resources);

  // ---------------------------------------------------------------------------
  // Instance Methods
  // ---------------------------------------------------------------------------

  /// Checks if a configuration value exists at the given path.
  ///
  /// Supports both flat keys (e.g., 'timeout') and hierarchical paths
  /// using dot notation (e.g., 'api.timeout').
  ///
  /// [s] - The configuration key or path to check.
  ///
  /// Returns `true` if any value exists at the path, `false` otherwise.
  bool exists(String s) {
    try {
      getObjectFromTree(resources, s);
      return true;
    } catch (ex) {
      // fall through
    }
    return resources[s] != null;
  }

  /// Retrieves the configuration value at the given path.
  ///
  /// Supports both flat keys (e.g., 'timeout') and hierarchical paths
  /// using dot notation (e.g., 'api.timeout').
  ///
  /// If the configuration is not found, returns the key itself as a fallback,
  /// which helps identify missing configuration during development.
  ///
  /// [s] - The configuration key or path to retrieve.
  ///
  /// Returns the value if found (can be any type), or the key [s] if not found.
  Object getText(String s) {
    try {
      dynamic value = getObjectFromTree(resources, s);
      return value;
    } catch (ex) {
      // fall through
    }
    return resources[s] != null ? resources[s]! : s;
  }
}
