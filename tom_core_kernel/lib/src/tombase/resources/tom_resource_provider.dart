/// Resource providers for managing application text resources and configuration.
///
/// This library provides singleton-based resource management for:
/// - **Text resources**: Localized strings, UI labels, and messages
/// - **Configuration resources**: Application settings and environment configuration
///
/// Both providers support hierarchical key access using dot notation (e.g., 'app.title')
/// and can be initialized from JSON maps or loader functions.
///
/// ## Bootstrap
///
/// Both providers must be installed explicitly during startup, before anything
/// reads from them; an uninstalled lookup throws rather than bootstrapping
/// itself. Applications with no bundle install an empty one — every lookup then
/// echoes its key, which is the intended degradation.
///
/// ## Example
///
/// ```dart
/// // Install the bundles once, at startup.
/// TomTextResourceProvider.setAppResourceProvider(
///   TomTextResourceProvider.from({
///     'app': {'title': 'My App', 'version': '1.0.0'},
///     'messages': {'welcome': 'Hello, World!'},
///   }),
/// );
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

import 'package:meta/meta.dart';

import '../json/map_merge_and_process.dart';
import '../little_things/exception_base.dart';
import '../observable/tom_observable_objects.dart';

// =============================================================================
// Exceptions
// =============================================================================

/// Thrown when the resource providers are used outside their contract.
///
/// Currently that is one condition on each provider — a lookup before a bundle
/// was installed (`resources.text_provider.not_installed`,
/// `resources.config_provider.not_installed`).
class TomResourceException extends TomException {
  TomResourceException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
    super.uuid,
    super.serverCallError,
  });
}

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
// The accessors above these helpers then collapse that distinction: a key that
// is present and holds null is indistinguishable from one that was never there.
// [exists] and [existsObject] both report `false`, the `*OrNull` accessors both
// return `null`, and [getText] and [getObject] both echo the key back. This is
// not an oversight but the absence of anywhere to put a third state — `bool` and
// `Object?` have no room for "present, but null". It matters in practice because
// bundles are usually JSON and translation tooling emits `null` for an
// untranslated string; such a key takes the missing branch, which is the
// intended fallback reached by an unintended route.
//
// The distinction is preserved where it is representable — in
// [getObjectFromTree], which returns `null` for a present null and throws for an
// absent key — and the bundle itself remains public. A caller that needs it
// reads `provider.resources.containsKey(key)` for a flat key, or calls
// [getObjectFromTree] directly for a dotted path.
//
// What a dotted segment can descend into is narrower than "anything nested":
// only a `Map` whose keys are *all* Strings. The test is on the runtime keys,
// not the declared type, so a `Map<String, String>` and a `Map<dynamic, dynamic>`
// holding String keys both traverse. Two shapes therefore do not:
//
//   - a `List`. `'items.0'` does not index it, and neither does anything past
//     it. Fetch the list whole and index it in Dart.
//   - a `Map` with even one non-String key. `'byCode.1'` cannot reach into a
//     `Map<int, String>`.
//
// Both remain reachable as *terminal* values — no descent is attempted on the
// last segment, so `getObject('items')` and `getObject('byCode')` return them
// intact. Only the path *through* them is closed, and closed silently: the walk
// throws, the flat leg finds nothing, and the fallback echoes the key, so a
// mistaken path renders as its own text instead of raising.
//
// That silence is why the guard around the walk is narrow. It absorbs
// `Exception` and nothing else, which is precisely the set [getObjectFromTree]
// raises to report a lookup outcome: a segment naming an absent key, or an
// interior segment with no subtree to descend into. Both are ordinary results
// of a lenient lookup and belong on the flat leg.
//
// Everything else — every `Error` subtype — travels out of the accessor
// untouched. An `Error` inside the walk is a programming fault, not a lookup
// outcome, and absorbing one would produce this module's worst failure mode:
// the fault falls through to the flat leg, misses there too, and renders as the
// key's own text, with no exception, no log line and nothing to grep for.
// Because the lenient fallback is the *designed* answer for a genuine miss,
// nothing downstream could tell the two apart. Letting the `Error` propagate is
// the only signal available, so it is kept.

/// Resolves the raw object at [path] in [resources].
///
/// Returns the tree value when the dotted [path] resolves, otherwise the
/// flat-key value `resources[path]`, otherwise `null`. Backs the object-family
/// accessors (any value type is accepted).
Object? _resolveObjectOrNull(Map<String, dynamic> resources, String path) {
  try {
    return getObjectFromTree(resources, path);
  } on Exception catch (_) {
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
  } on Exception catch (_) {
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
/// text content that may vary by locale or configuration.
///
/// It also holds values that are *not* Strings. [existsObject], [getObject] and
/// [getObjectOrNull] resolve a value of any type, which is what lets the
/// look-and-feel settings that travel with the text — TextStyles, Colors, and
/// similar — live in the same bundle instead of a second one. The bundle is a
/// `Map<String, dynamic>` either way; "text" names what the resources are *for*,
/// not what type they are.
///
/// The String family ([getText], [getTextOrNull], [exists]) reports a non-String
/// value as absent, so a Color is read with [getObject], not [getText]. Do not
/// move such a value to [TomConfigResourceProvider] on account of its type:
/// configuration is a different purpose, its accessors are a strict subset of
/// these, and it has no [appResourcesRevision] to re-render from.
///
/// The provider supports:
/// - Singleton access via [getAppResources], after an explicit install
/// - Hierarchical key access using dot notation
/// - Deferred *loading* with a loader function, separate from installation
/// - Direct initialization from a map
///
/// ## Usage
///
/// ### Setting up with a loader function
///
/// ```dart
/// // Install once at startup; the loader runs here, not at first access.
/// TomTextResourceProvider.setAppResourceProvider(
///   TomTextResourceProvider.load(() => jsonDecode(bundledStrings)
///       as Map<String, dynamic>),
/// );
///
/// // Access resources throughout the app
/// final resources = TomTextResourceProvider.getAppResources();
/// String title = resources.getText('screens.home.title');
/// ```
///
/// ### Setting up from an asynchronous source
///
/// The loader is synchronous by design — [getText] is synchronous, so the
/// bundle has to be in memory before anything reads it, and a constructor
/// cannot await. A source that only yields a `Future` (an asset, a file, a
/// downloaded pack) is therefore awaited *before* the install, and the
/// resolved map is handed to [TomTextResourceProvider.from]:
///
/// `readAsset` is the target's own asynchronous read — `rootBundle.loadString`
/// in a Flutter app, `(path) => File(path).readAsString()` on a server. This
/// package has no Flutter dependency, so the application supplies it.
///
/// ```dart
/// Future<void> initializeResources(
///   Future<String> Function(String assetPath) readAsset,
/// ) async {
///   final strings = await readAsset('assets/strings.json');
///   TomTextResourceProvider.setAppResourceProvider(
///     TomTextResourceProvider.from(jsonDecode(strings) as Map<String, dynamic>),
///   );
/// }
///
/// // Called once at startup, before anything reads a resource.
/// Future<void> main() async {
///   await initializeResources(readAsset);
/// }
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

  /// Optional loader function consulted by the default constructor.
  ///
  /// This declares *how* to build the bundle; [setAppResourceProvider] decides
  /// *when* it is installed. The split lets a platform layer name the source in
  /// one place while startup code installs it at the right moment:
  ///
  /// ```dart
  /// TomTextResourceProvider.loader =
  ///     () => jsonDecode(bundledStrings) as Map<String, dynamic>;
  /// // ... later, in main():
  /// TomTextResourceProvider.setAppResourceProvider(TomTextResourceProvider());
  /// ```
  ///
  /// The signature is synchronous, and deliberately so: [getText] is
  /// synchronous, so the map must exist by the time the constructor returns.
  /// The loader therefore only fits sources that can be produced without
  /// awaiting — a computed map, a compiled-in constant, an already-decoded
  /// string. Anything asynchronous (assets, files, network) is awaited in
  /// `main()` and installed with [TomTextResourceProvider.from]; see the class
  /// documentation.
  ///
  /// Setting this on its own installs nothing: [getAppResources] does not
  /// bootstrap itself, and will throw until the install above has run.
  ///
  /// It is also process-wide and persistent, which is the cost of the split.
  /// The field is not consumed by the construction it was set for: it stays set
  /// until something assigns `null`, and *every* later bare
  /// `TomTextResourceProvider()` — including one built for a purely local scope,
  /// far from the startup code that set it — is populated from it rather than
  /// starting empty. That is action at a distance, so set it once during
  /// bootstrap and leave it alone. Test suites that exercise the default
  /// constructor have to clear it between cases for the same reason.
  ///
  /// When both halves live in the same place, prefer
  /// [TomTextResourceProvider.load]: it takes the loader as an argument, so it
  /// populates the one provider being built and leaves no static state behind.
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

  /// Returns the process to the un-bootstrapped state, where [getAppResources]
  /// throws again.
  ///
  /// Deliberately does *not* bump [appResourcesRevision]. The revision exists so
  /// that observers can re-derive text from the new bundle, and after a clear
  /// there is no bundle to re-derive from — every observer's reaction would
  /// throw. Uninstalling is a teardown step, and teardown has no readers.
  ///
  /// Tests need this because installation is otherwise one-way: [getAppResources]
  /// refuses to bootstrap itself, so the very first install can only be observed
  /// by a test that can get back to "nothing installed".
  @visibleForTesting
  static void clearAppResourceProvider() {
    _resourceProvider = null;
  }

  /// Returns the application-wide text resource provider.
  ///
  /// Throws `resources.text_provider.not_installed` when
  /// [setAppResourceProvider] has not run. There is deliberately no lazy
  /// bootstrap: a self-installing lookup would put a bundle in place without
  /// bumping [appResourcesRevision], leaving observers registered before the
  /// first lookup showing raw keys for a bundle that had in fact been loaded.
  /// Because installation now happens in exactly one place, and that place
  /// notifies, the counter and the installed bundle cannot disagree.
  ///
  /// An application with no text resources still installs one — an empty
  /// bundle makes every lookup echo its key, which is the intended
  /// degradation. Not installing at all is a bootstrap bug, and this reports
  /// it at the first read rather than rendering the whole UI in raw keys.
  static TomTextResourceProvider getAppResources() {
    final provider = _resourceProvider;
    if (provider == null) {
      throw TomResourceException(
        "resources.text_provider.not_installed",
        "No application text resources are installed. Call "
            "TomTextResourceProvider.setAppResourceProvider(...) during "
            "startup, before anything reads text — "
            "setAppResourceProvider(TomTextResourceProvider.from({})) if the "
            "application has no bundle.",
        autoLog: true,
      );
    }
    return provider;
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
  /// The loader is called here, so the provider is fully populated by the time
  /// this returns. It must therefore produce the map without awaiting; for a
  /// source that only yields a `Future`, await it first and use
  /// [TomTextResourceProvider.from].
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
/// // Install once at startup; the loader runs here, not at first access.
/// TomConfigResourceProvider.setAppConfigProvider(
///   TomConfigResourceProvider.load(() => jsonDecode(bundledConfig)
///       as Map<String, dynamic>),
/// );
///
/// // Access configuration throughout the app
/// final config = TomConfigResourceProvider.getAppConfig();
/// final apiUrl = config.getObjectOrNull('api.baseUrl') as String? ?? '';
/// final timeout = config.getObjectOrNull('api.timeout') as int? ?? 5000;
/// ```
///
/// [getObjectOrNull] rather than [getText] here because [getText] echoes the
/// key back as a `String` on a miss, so `as int` throws — see [getText].
///
/// ### Setting up from an asynchronous source
///
/// The loader is synchronous, so a configuration file that only arrives via a
/// `Future` is awaited before the install and handed to
/// [TomConfigResourceProvider.from] — the same shape as
/// [TomTextResourceProvider], and usually the same `initializeResources()`:
///
/// ```dart
/// final contents = await readAsset('assets/config.json');
/// TomConfigResourceProvider.setAppConfigProvider(
///   TomConfigResourceProvider.from(jsonDecode(contents) as Map<String, dynamic>),
/// );
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

  /// Optional loader function consulted by the default constructor.
  ///
  /// Declares *how* to build the configuration; [setAppConfigProvider] decides
  /// *when* it is installed. Setting this on its own installs nothing, and it
  /// stays set afterwards, so every later bare `TomConfigResourceProvider()`
  /// is populated from it — see [TomTextResourceProvider.loader] for the
  /// two-phase pattern, that process-wide coupling, its single-statement
  /// alternative [TomConfigResourceProvider.load], and why asynchronous sources
  /// are awaited before the install rather than inside a loader.
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

  /// Returns the process to the un-bootstrapped state, where [getAppConfig]
  /// throws again. See [TomTextResourceProvider.clearAppResourceProvider].
  @visibleForTesting
  static void clearAppConfigProvider() {
    _configProvider = null;
  }

  /// Returns the application-wide configuration provider.
  ///
  /// Throws `resources.config_provider.not_installed` when
  /// [setAppConfigProvider] has not run. Configuration has no revision counter
  /// to keep honest, so this provider does not share the text provider's
  /// specific defect; it shares the contract because the two are used side by
  /// side, and a module in which one sibling refuses an unbootstrapped lookup
  /// while the other quietly answers "not configured" teaches nothing a caller
  /// can rely on.
  static TomConfigResourceProvider getAppConfig() {
    final provider = _configProvider;
    if (provider == null) {
      throw TomResourceException(
        "resources.config_provider.not_installed",
        "No application configuration is installed. Call "
            "TomConfigResourceProvider.setAppConfigProvider(...) during "
            "startup, before anything reads configuration — "
            "setAppConfigProvider(TomConfigResourceProvider.from({})) if the "
            "application has no configuration bundle.",
        autoLog: true,
      );
    }
    return provider;
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
  /// The loader is called here, so the provider is fully populated by the time
  /// this returns. It must therefore produce the map without awaiting; for a
  /// source that only yields a `Future`, await it first and use
  /// [TomConfigResourceProvider.from].
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
  /// **On a miss this returns the key itself, as a `String`** — the same
  /// lenient fallback the text provider uses, which makes a missing key visible
  /// rather than fatal. For configuration that has a sharp edge: the caller
  /// wanted an `int` or a `bool`, so a direct cast throws.
  ///
  /// ```dart
  /// config.getText('api.timeout') as int   // 30000 when present
  /// config.getText('api.retries') as int   // throws: String is not int
  /// config.getText('api.retries') as int?  // throws too — the miss value is
  ///                                        // a non-null String, not null
  /// ```
  ///
  /// The `TypeError` names `String` and `int` and never names the key, so it
  /// tells you nothing about which setting is missing. Use [getObjectOrNull]
  /// with a default instead — it is one lookup, and a miss cannot throw:
  ///
  /// ```dart
  /// final timeout = config.getObjectOrNull('api.timeout') as int? ?? 5000;
  /// ```
  ///
  /// Cast [getText] directly only where a miss is genuinely impossible, or
  /// behind an [exists] guard.
  ///
  /// [s] - The configuration key or path to retrieve.
  ///
  /// Returns the value if found (can be any type), or the key [s] if not found.
  Object getText(String s) => _resolveObjectOrNull(resources, s) ?? s;

  /// Retrieves the configuration value at the given path, or `null` when it is
  /// absent.
  ///
  /// The presence-reporting counterpart to [getText], mirroring
  /// [TomTextResourceProvider.getObjectOrNull]. Prefer it whenever the value is
  /// going to be cast: because a miss is `null` rather than the echoed key, a
  /// nullable cast with a default expresses "use the configured value, else
  /// this" in one lookup and one line.
  ///
  /// ```dart
  /// final timeout = config.getObjectOrNull('api.timeout') as int? ?? 5000;
  /// final dark = config.getObjectOrNull('features.darkMode') as bool? ?? false;
  /// ```
  ///
  /// A configured value of the wrong type still throws, which is the intent —
  /// that is a broken configuration file, not an absent setting.
  ///
  /// [s] - The configuration key or path to retrieve.
  ///
  /// Returns the value if found (can be any type), or null if not found.
  Object? getObjectOrNull(String s) => _resolveObjectOrNull(resources, s);
}
