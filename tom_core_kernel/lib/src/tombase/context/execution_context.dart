/// Tom Execution Context - Zone-based context propagation system.
///
/// This module provides a mechanism for propagating contextual information
/// through asynchronous call chains using Dart's Zone system. It enables
/// access to user principal data, tenant information, and other request-scoped
/// values without explicit parameter passing.
///
/// ## Key Features
///
/// - **Zone-Based Propagation**: Context values flow through async boundaries
/// - **Context Composition**: Contexts can be combined and extended
/// - **Type-Safe Entries**: Context entries are typed and validated
/// - **Default Providers**: Built-in providers for common context values
///
/// ## Usage
///
/// ```dart
/// // Run code with context
/// final context = TomExecutionContext({
///   'userId': TomContextEntry<String>(() => '12345'),
/// });
///
/// context.runInContext(() {
///   // Access context values from anywhere in this zone
///   final userId = getFromCurrentZone<String>();
/// });
/// ```
library;

import 'dart:async';

import '../little_things/little_things.dart';
import '../security/user_principal_aci.dart';

// =============================================================================
// Execution Context
// =============================================================================

/// A zone-based execution context for propagating request-scoped values.
///
/// [TomExecutionContext] uses Dart's Zone system to propagate contextual
/// information through synchronous and asynchronous call chains without
/// explicit parameter passing.
///
/// ## How It Works
///
/// When code runs inside a context via [runInContext] or [runInContextAsync],
/// the context values are stored in the zone and can be retrieved anywhere
/// in that zone using [getFromCurrentZone].
///
/// ## Context Composition
///
/// Contexts can be nested and combined:
///
/// ```dart
/// final baseContext = TomExecutionContext({'tenant': TomContextEntry(() => 'acme')});
/// final userContext = TomExecutionContext({'user': TomContextEntry(() => 'john')});
///
/// baseContext.runInContext(() {
///   userContext.runInContext(() {
///     // Both 'tenant' and 'user' are available here
///   });
/// });
/// ```
class TomExecutionContext {
  /// Map of context entry names to their entries.
  final Map<String, TomContextEntry> contextMap = {};

  /// Gets a context entry by name.
  /// [name] The name of the context entry.
  /// Returns the [TomContextEntry] if found, or null.
  TomContextEntry<T>? getEntry<T>(String name) {
    var entry = contextMap[name];
    if (entry != null && entry.type == T) {
      return entry as TomContextEntry<T>;
    }
    return null;
  }
  
  /// Get value of a context in the current zone type and named
  static T? getValueFromCurrentZone<T>(String name) {
    var ctx = getFromCurrentZone<TomExecutionContext>();
    if (ctx != null) {
      var entry = ctx.getEntry<T>(name);
      return entry?.value;
    }
    return null;
  }

  /// Creates an execution context with the given entries.
  ///
  /// [contextMap] A map of entry names to [TomContextEntry] objects.
  TomExecutionContext( Map<String, TomContextEntry> contextMap, { TomExecutionContext? parentContext }) {
    // Merge into this context's own fresh map, never the caller's argument:
    // the parent supplies the base entries and the child (`contextMap`)
    // overwrites them on collision, so the inner context wins and the source
    // map passed in is left unchanged (no aliasing mutation).
    if (parentContext != null) {
      this.contextMap.addAll(parentContext.contextMap);
    }
    this.contextMap.addAll(contextMap);
  }

  // ---------------------------------------------------------------------------
  // Context Modification
  // ---------------------------------------------------------------------------

  /// Adds or replaces a context entry.
  ///
  /// [name] The unique name for this entry.
  /// [entry] The context entry containing the value provider.
  void add(String name, TomContextEntry entry) {
    contextMap[name] = entry;
  }

  /// Removes all entries from this context.
  void clear() {
    contextMap.clear();
  }

  /// Merges another context's entries into this context.
  ///
  /// Entries from [other] will overwrite entries with the same name.
  void combineWith(TomExecutionContext other) {
    contextMap.addAll(other.contextMap);
  }

  // ---------------------------------------------------------------------------
  // Context Execution
  // ---------------------------------------------------------------------------

  /// Runs synchronous code within this context.
  ///
  /// Creates a new zone whose typed context entries are this context's entries
  /// merged with any [TomExecutionContext] already installed in the current
  /// zone. On a colliding key **this context's entry wins** (the inner/child
  /// context overrides the inherited one); the parent's map is never mutated.
  ///
  /// The optional [zoneValues] are arbitrary, untyped zone values threaded
  /// through alongside the typed context: they are wrapped in a
  /// [TomZoneValues] container that is merged with any [TomZoneValues] already
  /// in the current zone (existing values are preserved unless overridden by a
  /// matching key in [zoneValues]) and read back via
  /// [getValueFromCurrentZone]. Use [zoneValues] for ad-hoc values that do not
  /// warrant a typed [TomContextEntry]; use the context map for the structured,
  /// type-keyed entries.
  ///
  /// Example:
  /// ```dart
  /// final result = context.runInContext(() {
  ///   // Typed context entries and zone values available here
  ///   return computeResult();
  /// }, zoneValues: {'requestId': id});
  /// ```
  T runInContext<T>(T Function() body, {Map<Object?, Object?> zoneValues = const {}, }) {

    var newCtx = TomExecutionContext(contextMap, parentContext: getFromCurrentZone<TomExecutionContext>() );

    TomZoneValues? newZoneValues = TomZoneValues(zoneValues, existingValues: getFromCurrentZone<TomZoneValues>());
    
    return runZoned<T>(zoneValues: {TomExecutionContext: newCtx, TomZoneValues: newZoneValues}, body);
  }

  /// Runs asynchronous code within this context.
  ///
  /// Creates a new zone whose typed context entries are this context's entries
  /// merged with any [TomExecutionContext] already installed in the current
  /// zone. On a colliding key **this context's entry wins** (the inner/child
  /// context overrides the inherited one); the parent's map is never mutated.
  /// The merged context and zone values remain available across `await`
  /// boundaries inside [body].
  ///
  /// The optional [zoneValues] are arbitrary, untyped zone values threaded
  /// through alongside the typed context: they are wrapped in a
  /// [TomZoneValues] container that is merged with any [TomZoneValues] already
  /// in the current zone (existing values are preserved unless overridden by a
  /// matching key in [zoneValues]) and read back via
  /// [getValueFromCurrentZone]. See [runInContext] for the synchronous variant.
  ///
  /// Example:
  /// ```dart
  /// final result = await context.runInContextAsync(() async {
  ///   // Typed context entries and zone values available here and in awaited calls
  ///   return await fetchData();
  /// }, zoneValues: {'requestId': id});
  /// ```
  Future<T> runInContextAsync<T>(Future<T> Function() body, {Map<Object?, Object?> zoneValues = const {}, }) async {

    var newCtx = TomExecutionContext(contextMap, parentContext: getFromCurrentZone<TomExecutionContext>() );

    TomZoneValues? newZoneValues = TomZoneValues(zoneValues, existingValues: getFromCurrentZone<TomZoneValues>());

    return runZoned<Future<T>>(zoneValues: {TomExecutionContext: newCtx, TomZoneValues: newZoneValues}, body);
  }

}

// =============================================================================
// Zone Value Container
// =============================================================================

/// A mutable container for zone values.
///
/// Provides indexed access to zone values for easier manipulation.
class TomZoneValues {
  /// The underlying zone values map.
  late Map<Object?, Object?> zoneValues;

  /// Creates a zone values container.
  TomZoneValues( Map<Object?, Object?>? zoneValues, { TomZoneValues? existingValues}) {
    this.zoneValues = {};
    if (existingValues != null) {
      this.zoneValues.addAll(existingValues.zoneValues);
    }
    if (zoneValues != null) {
      this.zoneValues.addAll(zoneValues);
    }
  }

  /// Sets a zone value by key.
  void operator []=(Object? key, Object? value) {
    zoneValues[key] = value;
  }

  /// Gets a zone value by key.
  Object? operator [](Object? key) {
    return zoneValues[key];
  }

  /// Add all entries from another zone values map.
  TomZoneValues addAll(Map<Object?, Object?> other) {
    zoneValues.addAll(other);
    return this;
  }

  /// Clears all zone values.
  void clear() {
    zoneValues.clear();
  }

  /// Checks if a key exists in the zone values.
  bool containsKey(Object? key) {
    return zoneValues.containsKey(key); 
  }

  /// Removes a key from the zone values.
  /// Returns the removed value, or null if not found.
  Object? remove(Object? key) {
    return zoneValues.remove(key);
  }
}

// =============================================================================
// Context Entry
// =============================================================================

/// A typed context entry with a lazy value provider.
///
/// [TomContextEntry] wraps a function that provides a context value.
/// The value is computed lazily when accessed.
///
/// ## Type Parameter
///
/// The type parameter [T] specifies the type of value this entry provides.
///
/// ## Example
///
/// ```dart
/// // Static value
/// final entry = TomContextEntry<String>(() => 'constant');
///
/// // Dynamic value (computed each access)
/// final entry = TomContextEntry<DateTime>(() => DateTime.now());
///
/// // Value from zone
/// final entry = TomContextEntry<User>(() => getFromCurrentZone<User>());
/// ```
class TomContextEntry<T> {
  /// Function that provides the context value.
  final T? Function() contextFunction;

  /// Returns the type [T] of this entry's value.
  Type get type => T;

  /// Creates a context entry with the given value provider.
  const TomContextEntry(this.contextFunction);

  /// get the value from the context function
  T? get value => contextFunction();

  /// operator to get the value directly
  T? call() => contextFunction();

  /// ~ operator to get the value directly
  T? operator ~() => contextFunction();
}

// =============================================================================
// Context Providers
// =============================================================================

/// Static providers for common context values from [TomPrincipal].
///
/// These methods extract values from the current zone's [TomPrincipal] with
/// sensible defaults when no principal is present.
///
/// ## Available Providers
///
/// - **Organization/Application/Process**: Tenant identification
/// - **Language/Country/Timezone**: Server locale settings
/// - **ClientLanguage/ClientCountry/ClientTimezone**: Client locale settings
class TomContextProviders {
  /// Returns the organization from the current principal, or "default".
  static String getOrganization() {
    return getFromCurrentZone<TomPrincipal>()?.organization ?? "default";
  }

  /// Returns the application from the current principal, or "default".
  static String getApplication() {
    return getFromCurrentZone<TomPrincipal>()?.application ?? "default";
  }

  /// Returns the process from the current principal, or "default".
  static String getProcess() {
    return getFromCurrentZone<TomPrincipal>()?.process ?? "default";
  }

  /// Returns the server language from the current principal, or "en".
  static String getLanguage() {
    return getFromCurrentZone<TomPrincipal>()?.language ?? "en";
  }

  /// Returns the server country from the current principal, or "XX".
  static String getCountry() {
    return getFromCurrentZone<TomPrincipal>()?.country ?? "XX";
  }

  /// Returns the server timezone from the current principal, or "utc".
  static String getTimezone() {
    return getFromCurrentZone<TomPrincipal>()?.timezone ?? "utc";
  }

  /// Returns the client language from the current principal, or "en".
  static String getClientLanguage() {
    return getFromCurrentZone<TomPrincipal>()?.clientLanguage ?? "en";
  }

  /// Returns the client country from the current principal, or "XX".
  static String getClientCountry() {
    return getFromCurrentZone<TomPrincipal>()?.clientCountry ?? "XX";
  }

  /// Returns the client timezone from the current principal, or "utc".
  static String getClientTimezone() {
    return getFromCurrentZone<TomPrincipal>()?.clientTimezone ?? "utc";
  }
}

// =============================================================================
// Default Context Instance
// =============================================================================

/// Pre-configured execution context with standard context providers.
///
/// This context provides access to common principal-based values:
/// - `organization`, `application`, `process`
/// - `language`, `country`, `timezone`
/// - `clientLanguage`, `clientCountry`, `clientTimezone`
///
/// ## Usage
///
/// ```dart
/// tomExecutionContext.runInContext(() {
///   // Access organization, language, etc. via context map
///   final org = tomExecutionContext.contextMap['organization']?.contextFunction();
/// });
/// ```
var tomExecutionContext = TomExecutionContext({
  "organization": TomContextEntry<String>(TomContextProviders.getOrganization),
  "application": TomContextEntry<String>(TomContextProviders.getApplication),
  "process": TomContextEntry<String>(TomContextProviders.getProcess),
  "language": TomContextEntry<String>(TomContextProviders.getLanguage),
  "country": TomContextEntry<String>(TomContextProviders.getCountry),
  "timezone": TomContextEntry<String>(TomContextProviders.getTimezone),
  "clientLanguage": TomContextEntry<String>(
    TomContextProviders.getClientLanguage,
  ),
  "clientCountry": TomContextEntry<String>(
    TomContextProviders.getClientCountry,
  ),
  "clientTimezone": TomContextEntry<String>(
    TomContextProviders.getClientTimezone,
  ),
});
