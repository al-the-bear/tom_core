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
import '../observable/tom_observable_objects.dart';

// =============================================================================
// Shared Resolution Helpers
// =============================================================================

// Both providers resolve a key the same way: attempt a dot-notation tree walk
// first, then fall back to a flat-key lookup. [getObjectFromTree] *throws* when
// the path cannot be resolved, so a thrown walk always falls through to the
// flat lookup. It returns `null` only when the terminal key is present and
// holds null — a value, not an absence — and that resolves the walk, so the
// flat leg is not consulted. These two file-private helpers hold that
// resolution rule in one place; every accessor on both providers is expressed
// in terms of them, differing only in the missing-value fallback each returns.
//
// The accessors themselves still surface a present null as `null`, which their
// callers read as "not configured". These providers have no third state to
// report it with; the distinction is preserved where it is representable, in
// [getObjectFromTree] itself.

/// Resolves the raw object at [path] in [resources].
///
/// Returns the tree value when the dotted [path] resolves, otherwise the
/// flat-key value `resources[path]`, otherwise `null`. Backs the object-family
/// accessors (any value type is accepted).
Object? _resolveObjectOrNull(Map<String, dynamic> resources, String path) {
  try {
    return getObjectFromTree(resources, path);
  } catch (_) {
    // Path not resolvable as a tree walk — fall back to a flat-key lookup.
  }
  return resources[path];
}

/// Resolves the String value at [path] in [resources].
///
/// Returns the tree value when the dotted [path] resolves to a String,
/// otherwise the flat-key value when it is a String, otherwise `null`. Backs
/// the text-family accessors, which only surface String content. The flat-key
/// leg is consulted even when the tree walk lands on a non-String value, so a
/// literal dotted key (e.g. `'a.b'`) still resolves.
String? _resolveStringOrNull(Map<String, dynamic> resources, String path) {
  try {
    final value = getObjectFromTree(resources, path);
    if (value is String) return value;
  } catch (_) {
    // Path not resolvable as a tree walk — fall back to a flat-key lookup.
  }
  final flat = resources[path];
  return flat is String ? flat : null;
}

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

  /// Observable revision counter for the application-wide text bundle.
  ///
  /// Incremented every time the installed bundle changes — either because
  /// [setAppResourceProvider] installed a different provider, or because the
  /// [resources] map of the installed provider was replaced. Observe it to
  /// re-derive anything computed from the bundle (localised labels, in
  /// particular) when the application switches locale:
  ///
  /// ```dart
  /// // Retain the observer — observers are held weakly.
  /// final observer = TomTextResourceProvider.appResourcesRevision
  ///     >> (_) => rebuildLabels();
  /// ```
  ///
  /// In-place *mutation* of the map (`resources['a'] = 'b'`) cannot be
  /// detected; call [notifyAppResourcesChanged] after such an edit.
  static final TomInt appResourcesRevision = TomInt(0);

  // ---------------------------------------------------------------------------
  // Static Methods
  // ---------------------------------------------------------------------------

  /// Announces that the application-wide text bundle has changed.
  ///
  /// Bumps [appResourcesRevision], which notifies its observers. Call this
  /// after mutating the installed provider's [resources] map in place;
  /// installing a provider or assigning a new map does it automatically.
  static void notifyAppResourcesChanged() {
    appResourcesRevision | (~appResourcesRevision) + 1;
  }

  /// Sets the application-wide text resource provider instance.
  ///
  /// Use this method to replace the default provider with a custom
  /// pre-configured instance. Bumps [appResourcesRevision] so that text
  /// derived from the bundle can be re-resolved.
  ///
  /// [provider] - The provider instance to use application-wide.
  static void setAppResourceProvider(TomTextResourceProvider provider) {
    _resourceProvider = provider;
    notifyAppResourcesChanged();
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

  Map<String, dynamic> _resources = {};

  /// The map containing all text resources.
  ///
  /// Resources can be nested maps, with values accessed using dot notation.
  ///
  /// Assigning a new map to the *installed* provider bumps
  /// [appResourcesRevision]; mutating the map in place cannot be observed, so
  /// call [notifyAppResourcesChanged] after such an edit.
  Map<String, dynamic> get resources => _resources;

  set resources(Map<String, dynamic> value) {
    _resources = value;
    // Only the installed provider defines the application-wide bundle;
    // populating a not-yet-installed one (including from a constructor body)
    // must not announce a change.
    if (identical(this, _resourceProvider)) notifyAppResourcesChanged();
  }

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
  TomTextResourceProvider.from(Map<String, dynamic> resources)
      : _resources = resources;

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
  bool exists(String s) => _resolveStringOrNull(resources, s) != null;

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
  bool existsObject(String s) => _resolveObjectOrNull(resources, s) != null;

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
  Object getObject(String s) => _resolveObjectOrNull(resources, s) ?? s;

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
  Object? getObjectOrNull(String s) => _resolveObjectOrNull(resources, s);

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
  String getText(String s) => _resolveStringOrNull(resources, s) ?? s;

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
  String? getTextOrNull(String s) => _resolveStringOrNull(resources, s);
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
  bool exists(String s) => _resolveObjectOrNull(resources, s) != null;

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
  Object getText(String s) => _resolveObjectOrNull(resources, s) ?? s;
}
