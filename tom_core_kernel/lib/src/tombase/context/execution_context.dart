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
///   // Access context values from anywhere in this zone, by entry name
///   final userId = TomExecutionContext.getValueFromCurrentZone<String>('userId');
/// });
/// ```
///
/// ## Two reads, and which one to use
///
/// A zone is keyed by `Type`, and [runInContext] installs exactly two keys:
/// [TomExecutionContext] and [TomZoneValues]. Everything else lives *inside*
/// one of those two containers, so which read applies depends on what is being
/// fetched:
///
/// - **The containers themselves** are read by type, with
///   `getFromCurrentZone<TomExecutionContext>()` and
///   `getFromCurrentZone<TomZoneValues>()`.
/// - **A named context entry** is read by name, with
///   [TomExecutionContext.getValueFromCurrentZone]. Its type parameter selects
///   the entry's *value* type; it is not a zone key.
/// - **An ad-hoc zone value** passed as `zoneValues:` is read through the
///   container: `getFromCurrentZone<TomZoneValues>()?['requestId']`.
///
/// Reaching for the wrong one returns `null` rather than failing, so it is
/// worth being deliberate: `getFromCurrentZone<String>()` never sees an entry
/// named `'userId'`, however that entry is typed, because nothing ever
/// installs `String` as a zone key.
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
/// this context is installed in the zone under the [TomExecutionContext] type
/// key, so its entries are available anywhere in that zone. A single entry is
/// read by *name* with [getValueFromCurrentZone]; the context object itself is
/// read by *type* with `getFromCurrentZone<TomExecutionContext>()`. See the
/// library documentation for the full distinction.
///
/// ## Context Composition
///
/// Contexts can be nested and combined:
///
/// ```dart
/// final baseContext =
///     TomExecutionContext({'tenant': TomContextEntry<String>(() => 'acme')});
/// final userContext =
///     TomExecutionContext({'user': TomContextEntry<String>(() => 'john')});
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
  
  /// Reads the entry named [name] from the [TomExecutionContext] installed in
  /// the current zone, and returns its value.
  ///
  /// This is the read for a context entry. [T] is the entry's *value* type, not
  /// a zone key: the lookup finds the context by type and then the entry by
  /// name, so `getFromCurrentZone<T>()` does not reach an entry (see the
  /// library documentation).
  ///
  /// Returns `null` when no context is installed, when no entry carries [name],
  /// or when the entry found is not typed [T] — the same answer for all three,
  /// so a caller that needs to tell them apart should use [getEntry] on the
  /// context directly.
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
  /// [contextMap] A map of entry names to [TomContextEntry] objects. Write each
  /// entry's type parameter explicitly — `TomContextEntry<String>(...)`, not
  /// `TomContextEntry(...)` — or it infers `dynamic` from this parameter's type
  /// and no typed read will find it; see [TomContextEntry].
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
  /// matching key in [zoneValues]). They are read back through that container —
  /// `getFromCurrentZone<TomZoneValues>()?['requestId']` — and *not* with
  /// [getValueFromCurrentZone], which looks in the context map.
  ///
  /// Despite sharing its name with `runZoned`'s own `zoneValues:`, this
  /// parameter does not install its keys in the zone directly: they go into the
  /// [TomZoneValues] container, which is the only thing installed, so
  /// `Zone.current['requestId']` stays null. Use [zoneValues] for ad-hoc values
  /// that do not warrant a typed [TomContextEntry]; use the context map for the
  /// structured, named entries.
  ///
  /// Example:
  /// ```dart
  /// final result = context.runInContext(() {
  ///   final user = TomExecutionContext.getValueFromCurrentZone<String>('userId');
  ///   final requestId = getFromCurrentZone<TomZoneValues>()?['requestId'];
  ///   return computeResult(user, requestId);
  /// }, zoneValues: {'requestId': id});
  /// ```
  T runInContext<T>(T Function() body, {Map<Object?, Object?> zoneValues = const {}, }) {
    return runZoned<T>(zoneValues: _buildZoneValues(zoneValues), body);
  }

  /// Builds the zone-values map installed by [runInContext] /
  /// [runInContextAsync].
  ///
  /// The typed [TomExecutionContext] is this context's entries merged over any
  /// context already in the current zone (this context wins on collision, the
  /// parent's map is never mutated); the [TomZoneValues] container wraps
  /// [zoneValues] merged with any [TomZoneValues] already in the current zone.
  Map<Object, Object> _buildZoneValues(Map<Object?, Object?> zoneValues) {
    final newCtx = TomExecutionContext(
      contextMap,
      parentContext: getFromCurrentZone<TomExecutionContext>(),
    );
    final newZoneValues = TomZoneValues(
      zoneValues,
      existingValues: getFromCurrentZone<TomZoneValues>(),
    );
    return {TomExecutionContext: newCtx, TomZoneValues: newZoneValues};
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
  /// matching key in [zoneValues]). They are read back through that container —
  /// `getFromCurrentZone<TomZoneValues>()?['requestId']` — and *not* with
  /// [getValueFromCurrentZone], which looks in the context map. The keys are
  /// not installed in the zone under themselves either, so `Zone.current[key]`
  /// stays null. See [runInContext] for the synchronous variant.
  ///
  /// Example:
  /// ```dart
  /// final result = await context.runInContextAsync(() async {
  ///   // Entries and zone values stay available here and across every await
  ///   final user = TomExecutionContext.getValueFromCurrentZone<String>('userId');
  ///   final requestId = getFromCurrentZone<TomZoneValues>()?['requestId'];
  ///   return await fetchData(user, requestId);
  /// }, zoneValues: {'requestId': id});
  /// ```
  Future<T> runInContextAsync<T>(Future<T> Function() body, {Map<Object?, Object?> zoneValues = const {}, }) {
    return runZoned<Future<T>>(zoneValues: _buildZoneValues(zoneValues), body);
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
/// The type parameter [T] specifies the type of value this entry provides, and
/// [TomExecutionContext.getEntry] matches it exactly — an entry is only found
/// by a read for the very same [T].
///
/// **Always write [T] explicitly when registering an entry.** The context
/// constructor takes a `Map<String, TomContextEntry>`, which supplies
/// `TomContextEntry<dynamic>` as the downward inference context, so a raw
/// `TomContextEntry(() => 'acme')` written inside that map literal is a
/// `TomContextEntry<dynamic>` regardless of the value it returns — and every
/// typed read of it then yields `null`. (The same expression assigned to a
/// local infers `String`, which is what makes the trap easy to miss.)
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
  /// Reads a single field from the current zone's [TomPrincipal], falling back
  /// to [fallback] when no principal is installed (or the field is null).
  ///
  /// Centralises the principal-from-zone read shared by every provider getter,
  /// so a change to how the principal is resolved lands in one place.
  static String _fromPrincipal(
    String? Function(TomPrincipal principal) select,
    String fallback,
  ) {
    final principal = getFromCurrentZone<TomPrincipal>();
    return (principal == null ? null : select(principal)) ?? fallback;
  }

  /// Returns the organization from the current principal, or "default".
  static String getOrganization() =>
      _fromPrincipal((p) => p.organization, "default");

  /// Returns the application from the current principal, or "default".
  static String getApplication() =>
      _fromPrincipal((p) => p.application, "default");

  /// Returns the process from the current principal, or "default".
  static String getProcess() => _fromPrincipal((p) => p.process, "default");

  /// Returns the server language from the current principal, or "en".
  static String getLanguage() => _fromPrincipal((p) => p.language, "en");

  /// Returns the server country from the current principal, or "XX".
  static String getCountry() => _fromPrincipal((p) => p.country, "XX");

  /// Returns the server timezone from the current principal, or "utc".
  static String getTimezone() => _fromPrincipal((p) => p.timezone, "utc");

  /// Returns the client language from the current principal, or "en".
  static String getClientLanguage() =>
      _fromPrincipal((p) => p.clientLanguage, "en");

  /// Returns the client country from the current principal, or "XX".
  static String getClientCountry() =>
      _fromPrincipal((p) => p.clientCountry, "XX");

  /// Returns the client timezone from the current principal, or "utc".
  static String getClientTimezone() =>
      _fromPrincipal((p) => p.clientTimezone, "utc");
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
///   // Access organization, language, etc. by entry name
///   final org = TomExecutionContext.getValueFromCurrentZone<String>('organization');
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
