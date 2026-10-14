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
/// [TomExecutionContext] and [TomZoneValues]. **Both are reserved.** They are
/// ordinary `Type` keys, which is what makes the reads below possible — a
/// private sentinel would be collision-proof and unreadable — so a bare
/// `runZoned(zoneValues: {TomZoneValues: something})` can put a foreign value
/// under one of them. Use a key of your own instead; a collision made that way
/// is refused with `context.zone_key.reserved_key_holds_foreign_value` the
/// next time a run nests, rather than silently inheriting nothing. Passing
/// either type through [runInContext]'s own `zoneValues:` is not a collision:
/// that map is nested inside the container, not merged into the zone.
///
/// Everything else lives *inside* one of those two containers, so which read
/// applies depends on what is being fetched:
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
import 'dart:collection';

import '../little_things/exception_base.dart';
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
  /// The entries, keyed by name.
  final Map<String, TomContextEntry> _entries = {};

  /// The entries, keyed by name — a read-only view.
  ///
  /// Reading is the whole of what a consumer needs here, and the typed reads
  /// ([getEntry], [getValueFromCurrentZone]) are the ones to prefer: they
  /// answer with the entry's type rather than with `TomContextEntry<dynamic>`.
  /// This view is for the questions they cannot answer — how many entries
  /// there are, which names exist, iterating them for a diagnostic.
  ///
  /// It is unmodifiable because a context is installed in a zone and every
  /// caller in that zone reads the same object: a write through this map would
  /// be a write into everyone else's context, from a place none of them can
  /// see. Changing a context is done through [add], [clear] and [combineWith],
  /// which say so at the call site — and are meant for a context you own,
  /// typically while assembling one before it is ever run.
  ///
  /// The container that *is* meant to be written from inside a zone is
  /// [TomZoneValues]; see [runInContext] for why the two differ.
  late final Map<String, TomContextEntry> contextMap = UnmodifiableMapView(
    _entries,
  );

  /// Gets a context entry by name, when it can be read as [T].
  ///
  /// [name] The name of the context entry. Returns the entry when it is a
  /// `TomContextEntry<T>` *or a subtype of one*, and null otherwise — so an
  /// entry declared `TomContextEntry<int>` is found by `getEntry<num>` and by
  /// `getEntry<Object>`, and its value can be read as either. The test is
  /// Dart's own, which is why it follows the language's variance rather than
  /// a rule of this module's invention.
  ///
  /// An entry whose type argument is `dynamic` is **not** a
  /// `TomContextEntry<String>`, so it is still invisible to a typed read.
  /// That is not a leftover of the old exact match: `dynamic` is not a
  /// subtype of `String`, and the entry genuinely does not promise a String.
  /// It matters because the raw form is easy to write by accident — see
  /// [TomContextEntry] for how a map literal infers it.
  TomContextEntry<T>? getEntry<T>(String name) {
    final entry = _entries[name];
    return entry is TomContextEntry<T> ? entry : null;
  }

  /// Reads the entry named [name] from the [TomExecutionContext] installed in
  /// the current zone, and returns its value.
  ///
  /// This is the read for a context entry. [T] is the entry's *value* type, not
  /// a zone key: the lookup finds the context by type and then the entry by
  /// name, so `getFromCurrentZone<T>()` does not reach an entry (see the
  /// library documentation).
  ///
  /// Returns `null` when no context is installed, when no entry carries
  /// [name], or when the entry found cannot be read as [T] — the same answer
  /// for all three, so a caller that needs to tell them apart should use
  /// [getEntry] on the context directly.
  ///
  /// "Cannot be read as [T]" is assignability, not identity: an entry
  /// declared `TomContextEntry<int>` answers a `getValueFromCurrentZone<num>`
  /// read. An entry whose type argument is `dynamic` answers neither, since
  /// it promises nothing.
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
  ///
  /// **On a name held by both, [contextMap] wins over [parentContext].** The
  /// parent is the inherited background and this map is the foreground, which
  /// is also what makes a nested [runInContext] override the values it
  /// inherits: nesting builds a new context this way, with the installed one
  /// as the parent.
  ///
  /// Note that [combineWith] resolves a collision from the opposite end —
  /// there the *argument* wins over the receiver. Both are the same rule seen
  /// from different sides — the map applied last wins, and it is the one
  /// named closest to the call — but the receiver's entries surviving here
  /// and losing there is worth knowing before relying on either.
  TomExecutionContext(
    Map<String, TomContextEntry> contextMap, {
    TomExecutionContext? parentContext,
  }) {
    // Merge into this context's own fresh map, never the caller's argument:
    // the parent supplies the base entries and the child (`contextMap`)
    // overwrites them on collision, so the inner context wins and the source
    // map passed in is left unchanged (no aliasing mutation).
    if (parentContext != null) {
      _entries.addAll(parentContext.contextMap);
    }
    _entries.addAll(contextMap);
  }

  // ---------------------------------------------------------------------------
  // Context Modification
  // ---------------------------------------------------------------------------

  /// Adds or replaces a context entry.
  ///
  /// [name] The unique name for this entry.
  /// [entry] The context entry containing the value provider.
  void add(String name, TomContextEntry entry) {
    _entries[name] = entry;
  }

  /// Removes all entries from this context.
  void clear() {
    _entries.clear();
  }

  /// Merges another context's entries into this context.
  ///
  /// **On a name held by both, [other] wins over this context.** This is the
  /// mirror image of the constructor, where a context's own map wins over its
  /// [parentContext]: the same rule — the map applied last wins — but the
  /// receiver's entries survive construction and lose a merge. Reach for
  /// `other.combineWith(this)` when the receiver's values are the ones that
  /// should stand.
  void combineWith(TomExecutionContext other) {
    _entries.addAll(other.contextMap);
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
  /// Despite sharing its name, its type and its position with `runZoned`'s own
  /// `zoneValues:`, this parameter does not install its keys in the zone
  /// directly: they go into the [TomZoneValues] container, which — alongside the
  /// [TomExecutionContext] — is the only thing installed. `Zone.current[key]`
  /// therefore stays null for every key passed here, and that holds for a `Type`
  /// key just as much as for a `String` one: `zoneValues: {TomPrincipal: p}`
  /// does *not* make `getFromCurrentZone<TomPrincipal>()` resolve. (That form is
  /// correct when calling `runZoned` directly, which is what makes it an easy
  /// mistake to carry over — and a silent one, since the failed read yields null
  /// rather than an error.)
  ///
  /// The indirection is deliberate. Routing the values through a container is
  /// what makes them *mutable* — code inside the zone can write
  /// `getFromCurrentZone<TomZoneValues>()?['requestId'] = id` — and what makes
  /// them *mergeable* across nested runs, since an inner `runInContext` folds
  /// its values into the values it inherits instead of shadowing them wholesale.
  /// Raw zone values are immutable once installed and replace rather than merge,
  /// so neither is achievable by passing the map straight to `runZoned`.
  ///
  /// Use [zoneValues] for ad-hoc values that do not warrant a typed
  /// [TomContextEntry]; use the context map for the structured, named entries.
  ///
  /// Example:
  /// ```dart
  /// final result = context.runInContext(() {
  ///   final user = TomExecutionContext.getValueFromCurrentZone<String>('userId');
  ///   final requestId = getFromCurrentZone<TomZoneValues>()?['requestId'];
  ///   return computeResult(user, requestId);
  /// }, zoneValues: {'requestId': id});
  /// ```
  T runInContext<T>(
    T Function() body, {
    Map<Object?, Object?> zoneValues = const {},
  }) {
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
      parentContext: _inheritedOrRefuse<TomExecutionContext>(),
    );
    final newZoneValues = TomZoneValues(
      zoneValues,
      existingValues: _inheritedOrRefuse<TomZoneValues>(),
    );
    return {TomExecutionContext: newCtx, TomZoneValues: newZoneValues};
  }

  /// The [T] this run inherits from the zone, or null when there is none.
  ///
  /// [getFromCurrentZone] answers null for both "nothing there" and "something
  /// there that is not a [T]", which is the right answer for a *reader*: it
  /// asked for a [T] and there is none. It is the wrong answer here. The keys
  /// `TomExecutionContext` and `TomZoneValues` are reserved for these two
  /// containers, so a foreign value under one of them is not an absence —
  /// it is a collision, and inheriting nothing would silently drop every
  /// entry the enclosing run installed. Nesting would keep working and keep
  /// answering null, which is the shape of failure that survives a test suite.
  static T? _inheritedOrRefuse<T>() {
    final existing = Zone.current[T];
    if (existing == null || existing is T) return existing as T?;
    throw TomException(
      "context.zone_key.reserved_key_holds_foreign_value",
      "The zone key $T is reserved for the context module's own container, "
          "and holds a ${existing.runtimeType}. Something installed it with "
          "runZoned(zoneValues: {$T: ...}); use a key of your own, or read "
          "the container with getFromCurrentZone<$T>().",
      parameters: {"key": "$T", "found": existing.runtimeType},
      autoLog: true,
    );
  }

  /// Runs asynchronous code within this context.
  ///
  /// Creates a new zone whose typed context entries are this context's entries
  /// merged with any [TomExecutionContext] already installed in the current
  /// zone. On a colliding key **this context's entry wins** (the inner/child
  /// context overrides the inherited one); the parent's map is never mutated.
  ///
  /// This differs from [runInContext] only in its signature, not in the zone it
  /// installs: [body] is typed `Future<T> Function()` and its future is handed
  /// back, so `T` names the *awaited* value. Zone propagation is not the
  /// distinction — the merged context and zone values remain available across
  /// `await` boundaries under [runInContext] just as much as here, and reach
  /// callbacks scheduled from the body that fire after the call has returned.
  /// What this signature buys is that a body which drops its future is a
  /// compile error rather than a silent early return.
  ///
  /// The optional [zoneValues] are arbitrary, untyped zone values threaded
  /// through alongside the typed context: they are wrapped in a
  /// [TomZoneValues] container that is merged with any [TomZoneValues] already
  /// in the current zone (existing values are preserved unless overridden by a
  /// matching key in [zoneValues]). They are read back through that container —
  /// `getFromCurrentZone<TomZoneValues>()?['requestId']` — and *not* with
  /// [getValueFromCurrentZone], which looks in the context map. The keys are
  /// not installed in the zone under themselves either, so `Zone.current[key]`
  /// stays null — including for a `Type` key, which means
  /// `zoneValues: {TomPrincipal: p}` does not make
  /// `getFromCurrentZone<TomPrincipal>()` resolve. See [runInContext] for the
  /// synchronous variant and for why the values are routed through a container.
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
  Future<T> runInContextAsync<T>(
    Future<T> Function() body, {
    Map<Object?, Object?> zoneValues = const {},
  }) {
    return runZoned<Future<T>>(zoneValues: _buildZoneValues(zoneValues), body);
  }
}

// =============================================================================
// Zone Value Container
// =============================================================================

/// A mutable container for zone values.
///
/// Provides indexed access to zone values for easier manipulation.
///
/// This container — not the caller's keys — is what
/// [TomExecutionContext.runInContext] installs in the zone, under the
/// `TomZoneValues` type key. A value threaded through `zoneValues:` is
/// therefore read back through the container,
/// `getFromCurrentZone<TomZoneValues>()?[key]`; `Zone.current[key]` stays null
/// whatever the key's type.
///
/// The extra hop buys the two things raw zone values cannot offer: the entries
/// stay **mutable** after the zone is entered, and a nested `runInContext`
/// **merges** its values into the inherited ones (see the `existingValues`
/// constructor argument) instead of replacing them.
class TomZoneValues {
  /// The underlying zone values map.
  ///
  /// The map is mutable on purpose, and that is the whole point of this
  /// container: values routed through it can be written from inside the zone
  /// (`getFromCurrentZone<TomZoneValues>()?['requestId'] = id`), which raw
  /// zone values cannot. [TomExecutionContext.contextMap] is the opposite —
  /// a read-only view — because nothing is meant to write it from inside a
  /// zone. The two containers differ here on purpose; see
  /// [TomExecutionContext.runInContext].
  ///
  /// The *slot* is `final` even so. Reassigning it would swap the backing map
  /// of a container other code in the same zone is already reading through,
  /// which no amount of intended mutability asks for: writing a value is
  /// [operator []=], and emptying the map is [clear].
  final Map<Object?, Object?> zoneValues = {};

  /// Creates a zone values container.
  ///
  /// [existingValues] is laid down first and [zoneValues] over it, so a nested
  /// run's own values win on a colliding key — the same rule as
  /// [TomExecutionContext]'s constructor, and for the same reason.
  TomZoneValues(
    Map<Object?, Object?>? zoneValues, {
    TomZoneValues? existingValues,
  }) {
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
/// [TomExecutionContext.getEntry] reads it by assignability — an entry is
/// found by a read for [T] or for any supertype of it, so a
/// `TomContextEntry<int>` answers `getEntry<num>`.
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
/// - **Organization/Application/Process**: what the principal acts for inside
///   its tenant — the organization it logged in for, the application and the
///   process. The tenant itself is `TomTenantContext.currentId`.
/// - **Language/Country/Timezone**: Server locale settings
/// - **ClientLanguage/ClientCountry/ClientTimezone**: Client locale settings
///
/// ## Field readers, not a locale derivation
///
/// Each provider reads **one** field and answers a sentinel when it is absent.
/// The stored pair and the device pair are reported separately and on purpose:
/// a caller that needs a specific claim — an audit entry recording what the
/// device said, a diagnostic naming what the user chose — must be able to ask
/// for that one and not be handed a blend.
///
/// Choosing *between* them is a different question with a different answer, and
/// these providers deliberately do not answer it. To pick the locale to render
/// text in for a recipient, use `TomTextLocale.fromPrincipal` in
/// `tom_core_server`'s resources module, which applies the precedence rule
/// (stored preference over device) and answers `null` — not a guess — when the
/// principal names no locale at all.
///
/// Composing these providers into a locale instead does not merely duplicate
/// that rule, it gets a different one: `TomTextLocale(getLanguage(),
/// getCountry())` yields `en_XX` for a principal that names nothing, and `XX`
/// is a sentinel rather than a country (see [getCountry]). That combination is
/// refused by `TomTextLocale`'s country invariant, so the mistake fails rather
/// than silently rendering through a bundle nobody asked for.
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

  /// Returns the stored language from the current principal, or "en".
  ///
  /// The fallback is a value, not a derived answer: it says the principal named
  /// no language, not that this user reads English. A caller deciding what
  /// language to *write to somebody in* wants `TomTextLocale.fromPrincipal`,
  /// which distinguishes the two by answering `null`.
  static String getLanguage() =>
      _fromPrincipal((p) => p.language, TomClientContext.defaultLanguage);

  /// Returns the stored country from the current principal, or
  /// [TomClientContext.noCountry] — the non-locale sentinel described there,
  /// which a consumer building a locale key must drop rather than treat as a
  /// region.
  static String getCountry() =>
      _fromPrincipal((p) => p.country, TomClientContext.noCountry);

  /// Returns the server timezone from the current principal, or
  /// [TomClientContext.defaultTimezone].
  static String getTimezone() =>
      _fromPrincipal((p) => p.timezone, TomClientContext.defaultTimezone);

  /// Returns the client language from the current principal, or
  /// [TomClientContext.defaultLanguage].
  static String getClientLanguage() =>
      _fromPrincipal((p) => p.clientLanguage, TomClientContext.defaultLanguage);

  /// Returns the client country from the current principal, or
  /// [TomClientContext.noCountry].
  ///
  /// Here the sentinel is often the *stored* value rather than the fallback:
  /// [TomAuthenticationMessage.clientCountry] starts there, so a device that
  /// names no region sends it and it reaches the principal through an ordinary
  /// sign-in.
  static String getClientCountry() =>
      _fromPrincipal((p) => p.clientCountry, TomClientContext.noCountry);

  /// Returns the client timezone from the current principal, or
  /// [TomClientContext.defaultTimezone].
  static String getClientTimezone() =>
      _fromPrincipal((p) => p.clientTimezone, TomClientContext.defaultTimezone);
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
///
/// `final`, and deliberately so. Nothing in the workspace replaces it, the
/// dartdoc above describes only reading it, and the downstream re-export
/// already exposes it read-only — `tom_build_cli`'s `D4rtGlobals` publishes a
/// getter. A reassignable global would
/// let one importer swap the ambient context out from under every other, which
/// is a coupling nobody asked for and nothing uses. Build a `TomExecutionContext`
/// of your own and call `runInContext` on it when you need different providers.
final tomExecutionContext = TomExecutionContext({
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
