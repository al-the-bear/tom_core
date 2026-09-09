/// Tom Bean Locator - Dependency Injection and Service Locator System.
///
/// This module provides a lightweight dependency injection container that uses
/// Dart reflection to automatically discover, instantiate, and wire service beans.
/// It supports environment-specific and platform-specific bean implementations.
///
/// ## Key Features
///
/// - **Automatic Bean Discovery**: Classes annotated with `@TomComponent` are
///   automatically discovered and instantiated.
/// - **Interface-Based Injection**: Register beans by interface type for loose coupling.
/// - **Environment Support**: Different bean implementations for dev/test/prod.
/// - **Platform Support**: Platform-specific beans for iOS, Android, Web, etc.
///
/// ## Usage
///
/// ```dart
/// // Define a service interface
/// abstract class UserService {}
///
/// // Implement for specific environment
/// @tomReflector
/// @TomComponent(UserService)
/// class ProductionUserService implements UserService {}
///
/// // Access via TomBean
/// final userService = TomBean<UserService>().get();
/// ```
library;

import 'package:tom_basics/tom_basics.dart';
import 'package:tom_reflection/tom_reflection.dart';

import '../little_things/exception_base.dart';
import '../reflection/reflection.dart';

// =============================================================================
// Exception Classes
// =============================================================================

/// Exception thrown when bean locator operations fail.
///
/// This exception is used throughout the bean locator system to indicate
/// errors during:
/// - Bean instantiation and registration
/// - Bean resolution by name or type
/// - Duplicate bean detection
///
/// ## Exception Keys
///
/// This is the complete set the module raises — every failure inside the bean
/// locator arrives as this type, so `on TomBeanLocatorException` is a sufficient
/// handler.
///
/// - `beanlocator.initialization.duplicate_bean_with_name`: [TomBean.withName]
///   was given a name another bean already occupies. Use
///   [TomBean.overrideWithName] to replace a binding deliberately
/// - `beanlocator.initialization.duplicate_bean_with_type`: [TomBean.withType]
///   was given a type another bean already occupies, including one discovery
///   has bound. Use [TomBean.overrideWithType] to replace a binding deliberately
/// - `beanlocator.initialization.no_matching_implementation_found`: every
///   implementation of an interface was ruled out by its `@TomEnvironment` or
///   `@TomPlatform` selector, leaving discovery nothing to bind
/// - `beanlocator.initialization.ambiguous_implementation`: two implementations
///   qualify equally for one interface
/// - `beanlocator.bean_access.bean_not_found_by_name`: nothing is registered
///   under the name the handle resolves by
/// - `beanlocator.bean_access.bean_not_found_by_type`: a bean is registered
///   under the name, but is not an instance of the type the handle asks for
/// - `beanlocator.bean_access.no_bean_found_uninitialized`: nothing is
///   registered for the requested type — typically a handle resolved before
///   [initializeBeanContext] ran, or an interface with no component
/// - `beanlocator.bean_access.bean_not_assignable_to_type`: the requested type
///   *is* registered, but to something that is not an instance of it. The
///   sibling of the key above, and worth its own: a caller told the bean is
///   missing goes looking for a registration that is right there
/// - `beanlocator.bean_access.more_than_one_implementation_found`: two registered
///   beans satisfy one requested type
/// - `beanlocator.bean_access.no_bean_found_unknown_error`: The type walk failed
///   for a reason the locator does not model; the cause travels as the root
///   exception
/// - `beanlocator.environment.no_factory_for_environment`: `installByEnvironment`
///   has no factory for the active environment
/// - `beanlocator.environment.runtime_environment_not_initialized`: An operation
///   needed the active environment and the runtime was never configured. The
///   `operation` and `subject` parameters name what was being wired.
class TomBeanLocatorException extends TomException {
  /// Creates a new bean locator exception.
  ///
  /// [key] A unique identifier for the error type.
  /// [defaultUserMessage] Human-readable error message.
  TomBeanLocatorException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

// =============================================================================
// Component Marker Classes
// =============================================================================

/// Annotation to mark a class as a Tom component/service bean.
///
/// When applied to a class along with `@tomReflector`, the bean locator
/// will automatically discover and instantiate the class during initialization.
///
/// ## Usage
///
/// ### Without Interface (Concrete Type)
///
/// ```dart
/// @tomReflector
/// @tomComponent  // Uses TomNoInterface type
/// class MyService { ... }
/// ```
///
/// ### With Interface
///
/// ```dart
/// @tomReflector
/// @TomComponent(UserService)  // Registered as UserService interface
/// class MyUserServiceImpl implements UserService { ... }
/// ```
///
/// ## Platform/Environment-Specific Beans
///
/// Combine with `@TomEnvironment` or `@TomPlatform` annotations to provide
/// different implementations:
///
/// ```dart
/// @tomReflector
/// @TomComponent(UserService)
/// @TomEnvironment("test", isTest: true)
/// class MockUserService implements UserService { ... }
/// ```
///
/// A selector matches the active deployment when the **names** agree — which
/// `TomEnvironment` or `TomPlatform` instance carries the name is irrelevant, so
/// the environment `TomRuntime` is given may be built at runtime from
/// configuration. The name is the identity: `TomEnvironment("test")` and
/// `TomEnvironment("test", isTest: true)` are the same environment as far as
/// selection is concerned, and `"none"` is reserved for the sentinels that mean
/// "unconstrained".
class TomComponent extends Object {
  /// Creates a TomComponent annotation.
  ///
  /// [type] The interface type this component implements. Use [TomNoInterface]
  /// for concrete types without an interface.
  const TomComponent(this.type);

  /// The interface type this component is registered under.
  final Type type;

  /// Returns the interface type for this component.
  Type getType() {
    return type;
  }

  @override
  String toString() {
    return "TomComponent of $type";
  }
}

/// Marker interface indicating a null/missing component.
///
/// Library-private: it exists only to give [_nullComponent] a type, and no
/// consumer can meaningfully implement or reference it.
abstract class _TomNullInterface {}

/// Marker interface indicating a component without a specific interface.
///
/// Use this when a bean should be registered by its concrete type rather
/// than an interface.
abstract class TomNoInterface {}

/// Default component annotation for beans without a specific interface.
///
/// Equivalent to `@TomComponent(TomNoInterface)`.
const TomComponent tomComponent = TomComponent(TomNoInterface);

/// Internal null component marker.
const TomComponent _nullComponent = TomComponent(_TomNullInterface);

// =============================================================================
// Bean Container
// =============================================================================

/// A type-safe handle for accessing dependency-injected beans.
///
/// [TomBean] provides lazy resolution of beans registered in the bean context.
/// Beans can be resolved by type or by name.
///
/// ## Resolution by Type
///
/// ```dart
/// // Define service interface
/// abstract class UserService { ... }
///
/// // Register implementation (via @TomComponent annotation)
/// @tomReflector
/// @TomComponent(UserService)
/// class UserServiceImpl implements UserService { ... }
///
/// // Resolve by type
/// final service = TomBean<UserService>().get();
/// ```
///
/// ## Resolution by Name
///
/// ```dart
/// // Register with name
/// TomBean.withName("config", AppConfig());
///
/// // Resolve by name
/// final config = TomBean<AppConfig>.fromName("config").get();
/// ```
///
/// ## Callable Syntax
///
/// TomBean supports callable syntax for concise access:
///
/// ```dart
/// final TomBean<UserService> userService = TomBean();
/// // Later:
/// final user = userService().getUser(id);  // Calls get() then getUser()
/// ```
@tomReflector
class TomBean<T> {
  /// Beans registered under a [Type] — by [TomBean.withType], by
  /// [installByEnvironment], and by annotation discovery.
  ///
  /// Separate from [_tomBeansByName] rather than one `Map<Object, Object>`
  /// holding both, because the two are different namespaces that were only
  /// sharing a container. A `String` key can never equal a `Type` key, so the
  /// shared map was not *unsafe*; what it cost was that nothing said so. The
  /// declaration named `Object`, which is the one thing a registry should
  /// never be vague about; [_resolveByType] had to skip non-`Type` keys at
  /// runtime, a filter the type system expresses for free; and that walk
  /// iterated every named bean in order to reject it. Nothing reads the two
  /// together — resolution by name and resolution by type are separate
  /// methods with separate errors — so the only operation spanning both is
  /// emptying them, which [resetBeanContext] and a re-run of
  /// [initializeBeanContext] each do explicitly.
  static final Map<Type, Object> _tomBeansByType = {};

  /// Beans registered under a name, by [TomBean.withName].
  ///
  /// See [_tomBeansByType] for why the two registries are separate.
  static final Map<String, Object> _tomBeansByName = {};

  /// List of unresolved beans awaiting initialization.
  static final List<TomBean> _tomBeanList = [];

  /// Whether the bean context has been initialized.
  static bool _initialized = false;

  /// The resolved bean instance.
  T? _bean;

  /// The registered name for named beans.
  String? _name;

  // ---------------------------------------------------------------------------
  // Constructors
  // ---------------------------------------------------------------------------

  /// Creates an unresolved bean handle for type [T].
  ///
  /// The bean is resolved lazily when [get] is called.
  TomBean() {
    _tomBeanList.add(this);
  }

  /// Creates a bean handle that resolves by name.
  ///
  /// [name] The registered name of the bean.
  ///
  /// Example:
  /// ```dart
  /// final config = TomBean<AppConfig>.fromName("appConfig").get();
  /// ```
  ///
  /// The name need not be registered yet. A handle may be held as a field and
  /// the bean registered later in startup; the handle resolves on first use.
  /// [initializeBeanContext] does not force such a handle to resolve — see
  /// [_validateBeanReferences] — so a still-unregistered name is not a boot
  /// failure.
  factory TomBean.fromName(String name) {
    TomBean<T> result = TomBean();
    // Record the name unconditionally so that get() always routes through
    // _resolveByName, even when the bean is registered after this handle is
    // created (lazy named resolution). Pre-caching the instance is only an
    // optimisation for the already-registered case.
    result._name = name;
    Object? bean = _tomBeansByName[name];
    if (bean != null && bean is T) {
      result._bean = bean as T;
    }
    return result;
  }

  /// Registers a named bean and creates a handle for it.
  ///
  /// [name] The unique name for the bean.
  /// [bean] The bean instance to register.
  ///
  /// Throws [TomBeanLocatorException] if a bean with [name] already exists.
  ///
  /// Example:
  /// ```dart
  /// TomBean.withName("config", AppConfig());
  /// ```
  factory TomBean.withName(String name, Object bean) {
    if (_tomBeansByName[name] != null) {
      throw TomBeanLocatorException(
        "beanlocator.initialization.duplicate_bean_with_name",
        "Duplicate bean with name $name",
        parameters: {"name": name},
        autoLog: true,
      );
    }

    return TomBean<T>.overrideWithName(name, bean);
  }

  /// Registers a named bean, replacing whatever was registered under [name].
  ///
  /// Where [TomBean.withName] refuses a name that is already taken — the guard
  /// that stops two startup paths from silently clobbering each other — this
  /// factory is the deliberate exception, for substituting an implementation in
  /// a test.
  ///
  /// Example:
  /// ```dart
  /// TomBean.overrideWithName("config", StubAppConfig());
  /// ```
  ///
  /// Two consequences are worth knowing, because both fail silently:
  ///
  /// - A handle that has already resolved keeps the instance it resolved. Only
  ///   handles created (or first used) after the override see the replacement.
  /// - [initializeBeanContext] empties the registry, so an override must be
  ///   applied *after* the pass that would otherwise bind the original.
  factory TomBean.overrideWithName(String name, Object bean) {
    TomBean<T> result = TomBean();
    result._bean = bean as T;
    result._name = name;

    _tomBeansByName[name] = bean;
    return result;
  }

  /// Registers a bean by type and creates a handle for it.
  ///
  /// [t] The type to register the bean under.
  /// [bean] The bean instance to register.
  ///
  /// Throws [TomBeanLocatorException] if a bean with [t] already exists.
  ///
  /// Example:
  /// ```dart
  /// TomBean.withType(UserService, UserServiceImpl());
  /// ```
  ///
  /// Note: registering a type *before* [initializeBeanContext] takes precedence
  /// over any `@TomComponent` registration for the same type — discovery leaves
  /// a key that is already bound alone. To substitute an implementation once the
  /// context is initialized, use [TomBean.overrideWithType]; this factory throws
  /// there rather than replacing.
  ///
  /// **[bean] is not checked against [t] here, and cannot be.** [t] arrives as
  /// a `Type` *value*, and Dart has no expression that decides whether an
  /// object is an instance of one: `is` needs a type, not a value of type
  /// `Type`. Reflection does not close the gap either, and that is measured
  /// rather than assumed — `tomReflector.canReflectType` answers false for
  /// any class carrying no `@tomReflector`, which is precisely the population
  /// this factory exists to serve, and `superinterfaces` comes back empty even
  /// for a class it can reflect.
  ///
  /// So the check happens where the relation *is* decidable: resolving
  /// `TomBean<X>()` has a real type argument, and a bean registered under `X`
  /// that is not an `X` raises
  /// `beanlocator.bean_access.bean_not_assignable_to_type` naming both the
  /// type asked for and the type found — rather than reporting the bean as
  /// missing, which sends the reader looking for a registration that is in
  /// fact right there.
  factory TomBean.withType(Type t, Object bean) {
    if (_tomBeansByType[t] != null) {
      throw TomBeanLocatorException(
        "beanlocator.initialization.duplicate_bean_with_type",
        "Duplicate bean with type $t",
        parameters: {"type": t},
        autoLog: true,
      );
    }

    return TomBean<T>.overrideWithType(t, bean);
  }

  /// Registers a bean by type, replacing whatever was registered under [t].
  ///
  /// Where [TomBean.withType] refuses a type that is already bound — the guard
  /// that stops two startup paths from silently clobbering each other — this
  /// factory is the deliberate exception, for substituting an implementation in
  /// a test:
  ///
  /// ```dart
  /// initializeBeanContext();
  /// TomBean.overrideWithType(UserService, MockUserService());
  /// ```
  ///
  /// Three consequences are worth knowing, because all three fail silently:
  ///
  /// - A handle that has already resolved keeps the instance it resolved. Only
  ///   handles created (or first used) after the override see the replacement.
  /// - [initializeBeanContext] empties the registry, so an override must be
  ///   applied *after* the pass, and re-applied after every later pass.
  /// - [bean] must be assignable to the type consumers ask for. It is not
  ///   checked here — see [TomBean.withType] for why that is not possible —
  ///   and a mismatch is raised by resolution as
  ///   `beanlocator.bean_access.bean_not_assignable_to_type`.
  factory TomBean.overrideWithType(Type t, Object bean) {
    TomBean<T> result = TomBean();
    result._bean = bean as T;

    _tomBeansByType[t] = bean;
    return result;
  }

  /// Selects and installs exactly one implementation of [T] by the current
  /// runtime environment.
  ///
  /// [factories] maps an environment name to the factory that builds the
  /// implementation for that environment. The active environment name — taken
  /// from [environment] when given, otherwise
  /// [TomRuntime.getCurrentEnvironment] — selects which single factory runs;
  /// the built instance is registered by type via [TomBean.withType], so a
  /// later `TomBean<T>().get()` resolves it.
  ///
  /// This is the environment-selector form of dependency injection: the caller
  /// picks the environment *name* (e.g. from a launch flag), and the locator
  /// picks the collaborator from that name. Exactly one factory runs and
  /// exactly one bean is registered — there is no runtime dispatcher choosing
  /// between two installed implementations.
  ///
  /// Throws [TomBeanLocatorException] if no factory is registered for the
  /// active environment. A missing mapping is a wiring bug, not a silent
  /// fallback. The same exception type — key
  /// `beanlocator.environment.runtime_environment_not_initialized` — reports an
  /// unconfigured runtime when [environment] is omitted and there is no active
  /// environment to read. Passing [environment] answers that question at the
  /// call site, so it needs no configured runtime at all.
  static TomBean<T> installByEnvironment<T>(
    Map<String, T Function()> factories, {
    String? environment,
  }) {
    final env =
        environment ??
        _requireCurrentEnvironment("installByEnvironment", T).env;
    final factory = factories[env];
    if (factory == null) {
      throw TomBeanLocatorException(
        "beanlocator.environment.no_factory_for_environment",
        "No bean factory registered for environment '$env'.",
        parameters: {"environment": env, "available": factories.keys.toList()},
        autoLog: true,
      );
    }
    return TomBean<T>.withType(T, factory() as Object);
  }

  // ---------------------------------------------------------------------------
  // Static Accessors
  // ---------------------------------------------------------------------------

  /// Returns the bean registered for [type], or null if not found.
  static Object? getBeanByType(Type type) {
    return _tomBeansByType[type];
  }

  /// Returns the bean registered with [name], or null if not found.
  static Object? getBeanByName(String name) {
    return _tomBeansByName[name];
  }

  /// Clears all registered beans and resets the initialization flag.
  ///
  /// This empties the global bean context, drops every pending unresolved
  /// handle, and marks the context as uninitialized so a subsequent
  /// [initializeBeanContext] starts from a clean slate.
  ///
  /// The bean context is process-global static state. Without a way to clear
  /// it, registrations leak between independent units of work — most visibly in
  /// tests, where a bean registered by one test would otherwise still be
  /// present in the next. Call this between such units to isolate them.
  static void resetBeanContext() {
    _tomBeansByType.clear();
    _tomBeansByName.clear();
    _tomBeanList.clear();
    _initialized = false;
  }

  // ---------------------------------------------------------------------------
  // Instance Methods
  // ---------------------------------------------------------------------------

  /// Returns the type parameter [T].
  Type getType() {
    return T;
  }

  /// Resolves and returns the bean instance.
  ///
  /// Resolution strategy:
  /// 1. If already resolved, return cached instance
  /// 2. If named, look up by name in context
  /// 3. Otherwise, search by type assignability
  ///
  /// Only a *successful* resolution caches. A handle that failed — nothing
  /// registered, or two implementations satisfying the same type — holds no
  /// instance, so every later call re-runs the lookup and throws again with the
  /// same key and the same parameters. A failure that answered once and then
  /// started returning a value would be worse than the failure.
  ///
  /// Throws [TomBeanLocatorException] if resolution fails.
  T get() {
    if (_bean != null) {
      return _bean!;
    }

    if (_name != null) {
      return _resolveByName();
    }

    return _resolveByType();
  }

  /// Resolves bean by registered name.
  T _resolveByName() {
    var obj = _tomBeansByName[_name];

    if (obj == null) {
      throw TomBeanLocatorException(
        "beanlocator.bean_access.bean_not_found_by_name",
        "Bean named $_name of type $T not found.",
        parameters: {"name": _name},
        autoLog: true,
      );
    }

    if (obj is T) {
      _bean = obj as T;
    } else {
      throw TomBeanLocatorException(
        "beanlocator.bean_access.bean_not_found_by_type",
        "Bean named $_name had type ${obj.runtimeType}, expected $T",
        parameters: {"type": T, "name": _name},
        autoLog: true,
      );
    }

    tomLog.trace(
      "Named bean $_name linked to type ${_bean.runtimeType} instance $_bean.",
    );
    return _bean!;
  }

  /// Resolves bean by type assignability.
  ///
  /// The walk collects **every** assignable bean before deciding anything, and
  /// nothing writes [_bean] until exactly one candidate is known. That ordering
  /// is the point: assigning the first match as it is found and only raising on
  /// the second leaves the handle holding that first match, so [get] short-
  /// circuits on the cache and every later call answers with whichever
  /// implementation the registry happened to iterate first — the arbitrary
  /// resolution the ambiguity error exists to prevent, and silent, because the
  /// caller who receives the answer is not the caller who saw the throw.
  /// Ambiguity is an error, not a preference, so it is raised on every call.
  T _resolveByType() {
    final matches = <MapEntry<Type, T>>[];

    try {
      for (final registration in _tomBeansByType.entries) {
        if (_assignableFrom(registration.value)) {
          matches.add(MapEntry(registration.key, registration.value as T));
        }
      }
    } on TomException {
      rethrow;
    } catch (exception, stacktrace) {
      throw TomBeanLocatorException(
        "beanlocator.bean_access.no_bean_found_unknown_error",
        "TomBean of type $T could not be resolved. "
            "Exception $exception Stacktrace $stacktrace",
        parameters: {"type": T},
        rootException: exception,
        autoLog: true,
      );
    }

    if (matches.isEmpty) {
      // Nothing assignable. Before reporting an absence, ask whether the key
      // itself is bound: a bean sitting under exactly this type and failing
      // the assignability test is not a missing registration but a wrong one,
      // and the two send the reader looking in different places.
      //
      // This is also the only point at which that relation can be decided at
      // all. [TomBean.withType] takes the key as a `Type` value, and Dart has
      // no expression relating a `Type` to an instance — see the note there
      // for why reflection does not close the gap either. Here `T` is a real
      // type argument, so `is` answers, and a bean mis-keyed at registration
      // is named here or nowhere.
      final misKeyed = _tomBeansByType[T];
      if (misKeyed != null) {
        throw TomBeanLocatorException(
          "beanlocator.bean_access.bean_not_assignable_to_type",
          "Bean registered under type $T is a ${misKeyed.runtimeType}, "
              "which is not a $T",
          parameters: {"type": T, "registered": misKeyed.runtimeType},
          autoLog: true,
        );
      }

      throw TomBeanLocatorException(
        "beanlocator.bean_access.no_bean_found_uninitialized",
        "Uninitialized bean without name for type $T",
        parameters: {"type": T},
        autoLog: true,
      );
    }

    if (matches.length > 1) {
      final first = matches[0];
      final second = matches[1];
      throw TomBeanLocatorException(
        "beanlocator.bean_access.more_than_one_implementation_found",
        "More than one bean for type $T found (${matches.length} candidates), "
            "found additional bean of type ${second.key} after having found "
            "${first.value.runtimeType} instance: ${first.value}",
        parameters: {
          "bean": first.value,
          "beanType": first.value.runtimeType,
          "type": T,
          "secondBean": second.value,
          "secondType": second.key,
          "matchCount": matches.length,
        },
        autoLog: true,
      );
    }

    _bean = matches.single.value;
    tomLog.trace(
      "Bean of type $T linked to type ${_bean.runtimeType} instance $_bean.",
    );
    return _bean!;
  }

  /// Callable shortcut for [get].
  ///
  /// Example:
  /// ```dart
  /// final TomBean<UserService> service = TomBean();
  /// final user = service().getUser(123);  // Equivalent to service.get().getUser(123)
  /// ```
  T call() {
    return get();
  }

  /// Checks if [service] is assignable to type [T].
  bool _assignableFrom(Object service) {
    return service is T;
  }

  /// Whether this handle names a bean that has not been registered yet.
  ///
  /// Such a handle is the "resolve before registration" case: the name was
  /// recorded now and [TomBean.withName] will supply the instance later. It is
  /// deliberately excluded from startup validation — see
  /// [_validateBeanReferences].
  bool get _awaitsNamedRegistration =>
      _bean == null && _name != null && !_tomBeansByName.containsKey(_name);

  /// Returns the bean type [T].
  Type getBeanType() {
    return T;
  }
}

// =============================================================================
// Runtime Access
// =============================================================================

/// Returns the active environment, raising the locator's own exception when the
/// runtime has not been configured.
///
/// [TomRuntime.getCurrentEnvironment] signals an unconfigured runtime with a
/// bare `Exception`. That is `tom_basics`' contract, not this module's: every
/// example and every line of the bean locator's documentation teaches callers
/// to write `on TomBeanLocatorException`, and a bare `Exception` walks straight
/// past such a handler — the caller does not get a worse message, it gets no
/// handler at all. The bare exception also names neither the bean nor the
/// interface whose selector asked for the environment, which is the only
/// context that makes the failure actionable: "environment has not been
/// initialized" does not say *what was being wired* when it was needed.
///
/// So the boundary is translated here, once, rather than at each call site.
/// [operation] names what the locator was doing and [subject] what it was doing
/// it to; both travel in the exception parameters so a handler can react to
/// them without parsing the message.
TomEnvironment _requireCurrentEnvironment(String operation, Object subject) {
  try {
    return TomRuntime.getCurrentEnvironment();
  } on TomException {
    rethrow;
  } catch (exception) {
    throw TomBeanLocatorException(
      "beanlocator.environment.runtime_environment_not_initialized",
      "No runtime environment is configured, but $operation for $subject "
          "requires one. Configure the runtime (initializeRuntime() or "
          "TomRuntime.setCurrentEnvironment(...)) before the bean context.",
      parameters: {"operation": operation, "subject": "$subject"},
      rootException: exception,
      autoLog: true,
    );
  }
}

// =============================================================================
// Selector Matching
// =============================================================================

/// Whether the `@TomEnvironment` selector [selector] designates [active].
///
/// Environments are matched **by name**, never by instance. `TomRuntime` keys
/// its registry by name — [TomRuntime.setCurrentEnvironment] takes a name, and
/// registering a second environment under a name already present is a duplicate
/// rather than a second environment — so the name *is* the environment's
/// identity, and this comparison simply agrees with that.
///
/// The distinction is not academic. An annotation is necessarily a `const`, and
/// const expressions are canonicalised, so comparing instances happens to work
/// for as long as the value handed to the runtime is written as an identical
/// `const`. Nothing keeps it written that way: `TomRuntime`'s own documented
/// setup builds environments with a plain constructor call, and an application
/// reading its environment name from configuration has no `const` to write. An
/// instance comparison would then match nothing, and the report would be
/// [initializeBeanContext] announcing that an interface has no implementation
/// while the implementation sits right there carrying what looks like the very
/// same selector.
bool _environmentMatches(TomEnvironment selector, TomEnvironment? active) =>
    selector.env == active?.env;

/// Whether the `@TomPlatform` selector [selector] designates [active].
///
/// Platforms are matched by name for the same reason environments are — see
/// [_environmentMatches]. A null [active] matches nothing, so a component that
/// constrains its platform stays unbound until the platform is known rather
/// than being bound on the assumption that it fits.
bool _platformMatches(TomPlatform selector, TomPlatform? active) =>
    selector.name == active?.name;

// =============================================================================
// Bean Context Initialization
// =============================================================================

/// Initializes the bean context by discovering and instantiating all beans.
///
/// This function scans all classes annotated with `@tomReflector` for
/// `@TomComponent` annotations and:
///
/// 1. Instantiates classes marked with `@tomComponent` (no interface)
/// 2. Finds best-match implementations for interface-based components
/// 3. Validates all bean references
///
/// ## Initialization Order
///
/// 1. Clear any existing registry if re-initializing
/// 2. Discover annotated classes via reflection
/// 3. Filter by environment and platform constraints
/// 4. Instantiate and register beans
/// 5. Validate the pending TomBean references
///
/// ## Which handles are validated
///
/// Every handle constructed since the last pass (or since
/// [TomBean.resetBeanContext]) is pending, and validation resolves it — so a
/// handle created *between* two passes is checked by the second one exactly as
/// a handle created before the first is checked by the first. Whether a
/// dependency is verified must not depend on which side of a call it happened
/// to be declared on.
///
/// Handles awaiting a named registration are the documented exception; see
/// [_validateBeanReferences].
///
/// ## Usage
///
/// ```dart
/// // Set up the runtime first. The environment has to be registered before it
/// // can be made current — `setCurrentEnvironment` resolves a *name* against
/// // the registry and falls back when the name is unknown.
/// TomRuntime.addEnvironment(const TomEnvironment("dev"));
/// TomRuntime.setCurrentEnvironment("dev");
///
/// // The platform likewise: `TomRuntime.initializePlatform()` detects it, but
/// // only once `TomPlatformUtils.setCurrentPlatform` has supplied a real
/// // implementation — the fallback throws. Naming it directly also works.
/// TomRuntime.setCurrentPlatform(platformLinux);
///
/// // Then initialize beans
/// initializeBeanContext();
///
/// // Now beans can be resolved
/// final service = TomBean<MyService>().get();
/// ```
void initializeBeanContext() {
  // Re-initializing rebuilds the registry from scratch. The pending-handle list
  // is *not* cleared here: those handles are references still held by live
  // code, and dropping them unresolved would silently exempt everything
  // declared since the previous pass from validation.
  if (TomBean._initialized) {
    TomBean._tomBeansByType.clear();
    TomBean._tomBeansByName.clear();
  }

  _discoverAndInstantiateBeans();
  _validateBeanReferences();

  // Validated handles have served their purpose; keeping them would grow the
  // list for the lifetime of the process.
  TomBean._tomBeanList.clear();
  TomBean._initialized = true;
}

/// Discovers and instantiates all annotated bean classes.
void _discoverAndInstantiateBeans() {
  for (var t in tomReflector.annotatedClasses) {
    TomComponent tc =
        t.metadata.firstWhere(
              (md) => md is TomComponent,
              orElse: () => _nullComponent,
            )
            as TomComponent;

    if (tc == _nullComponent) continue;

    if (tc.getType() == TomNoInterface) {
      _instantiateConcreteBean(t);
    } else {
      _instantiateInterfaceBean(t, tc);
    }
  }
}

/// Instantiates a bean without an interface (concrete type).
void _instantiateConcreteBean(ClassMirror classMirror) {
  tomLog.trace(
    "Service class candidate ${classMirror.qualifiedName} without interface found.",
  );

  // A key that is already bound is an answer, not a candidate — so leave it
  // alone, exactly as _instantiateInterfaceBean does. This is what makes
  // "register before initializeBeanContext()" mean the same thing for a
  // concrete bean as it does for an interface implementation. The check runs
  // before newInstance so the pass does not construct an object it would only
  // discard.
  if (TomBean._tomBeansByType[classMirror.reflectedType] != null) {
    tomLog.trace(
      "Service instance for ${classMirror.reflectedType} already assigned to "
      "${TomBean._tomBeansByType[classMirror.reflectedType]}",
    );
    return;
  }

  // Check environment constraint. The runtime is consulted only for a class
  // that actually carries a selector, so an unannotated bean is discoverable
  // without a configured runtime — the lookup stays inside the condition.
  for (var meta in classMirror.metadata) {
    if (meta is TomEnvironment &&
        !_environmentMatches(
          meta,
          _requireCurrentEnvironment(
            "environment selection",
            classMirror.qualifiedName,
          ),
        )) {
      tomLog.trace(
        "Discarding service class $classMirror because environments don't match.",
      );
      return;
    }
    if (meta is TomPlatform &&
        !_platformMatches(meta, TomRuntime.getCurrentPlatform())) {
      tomLog.trace(
        "Discarding service class $classMirror because platforms don't match.",
      );
      return;
    }
  }

  var obj = classMirror.newInstance("", []);
  tomLog.info(
    "Service class ${classMirror.qualifiedName} has been instantiated "
    "and assigned for ${obj.runtimeType}. Instance is $obj",
  );
  TomBean._tomBeansByType[obj.runtimeType] = obj;
}

/// Instantiates a bean that implements an interface.
void _instantiateInterfaceBean(ClassMirror classMirror, TomComponent tc) {
  if (TomBean._tomBeansByType[tc.getType()] != null) {
    tomLog.trace(
      "Service Instance for ${tc.getType()} already assigned to "
      "${TomBean._tomBeansByType[tc.getType()]}",
    );
    return;
  }

  tomLog.trace("Determining implementation for ${tc.getType()}");
  List<_TomImplementationInfo> implementors = _findImplementors(tc);

  ClassMirror? implementation = _TomImplementationInfo._findImplementation(
    implementors,
    tc,
  );

  if (implementation != null) {
    var obj = implementation.newInstance("", []);
    TomBean._tomBeansByType[tc.getType()] = obj;
    tomLog.info(
      "Service class ${implementation.qualifiedName} has been instantiated "
      "and assigned for interface ${tc.getType()} service instance is $obj.",
    );
  } else {
    throw TomBeanLocatorException(
      "beanlocator.initialization.no_matching_implementation_found",
      "No matching implementation for ${tc.getType()} found.",
      parameters: {"type": tc.getType()},
      autoLog: true,
    );
  }
}

/// Finds all classes that implement the given component's interface.
List<_TomImplementationInfo> _findImplementors(TomComponent tc) {
  List<_TomImplementationInfo> implementors = [];

  for (var otherType in tomReflector.annotatedClasses) {
    TomComponent otc =
        otherType.metadata.firstWhere(
              (md) => md is TomComponent,
              orElse: () => _nullComponent,
            )
            as TomComponent;

    if (otc != _nullComponent && otc.getType() == tc.getType()) {
      _TomImplementationInfo info = _TomImplementationInfo(
        otherType,
        otherType.metadata.firstWhere(
              (md) => md is TomEnvironment,
              orElse: () => noTomEnvironment,
            )
            as TomEnvironment,
        otherType.metadata.firstWhere(
              (md) => md is TomPlatform,
              orElse: () => noTomPlatform,
            )
            as TomPlatform,
      );
      implementors.add(info);
    }
  }

  return implementors;
}

/// Resolves every pending handle so that wiring errors surface at startup.
///
/// Validation vouches for what the pass itself could have supplied. Discovery
/// registers under `Type` keys only — a concrete bean under its runtime type,
/// an interface implementation under the interface — so a typed handle that is
/// still unresolvable at the end of the pass names a binding nothing produced.
/// That is a wiring bug, and reporting it at boot is the whole point of
/// validating at all.
///
/// A handle awaiting a *named* registration is a different case and is skipped.
/// Nothing in discovery ever registers a name: names enter the registry solely
/// through the imperative [TomBean.withName]. Resolving such a handle here would
/// therefore demand, at boot, something the pass has no way to provide — turning
/// the supported "create the handle now, register the bean later in startup"
/// pattern into a startup failure for the sole reason that the handle happened
/// to exist when the pass ran.
///
/// The skip is narrow on purpose. A named handle whose name *is* registered is
/// validated like any other, so a name bound to the wrong type is still caught
/// at boot — that question is answerable now, and no later registration repairs
/// a mismatch.
void _validateBeanReferences() {
  for (var bean in TomBean._tomBeanList) {
    if (bean._awaitsNamedRegistration) continue;
    bean();
  }
}

// =============================================================================
// Implementation Resolution
// =============================================================================

/// Internal class to track implementation candidates and their constraints.
///
/// Used during bean discovery to select the best matching implementation
/// based on environment and platform constraints.
class _TomImplementationInfo {
  /// The class mirror for this implementation.
  final ClassMirror classMirror;

  /// The environment constraint for this implementation.
  final TomEnvironment environment;

  /// The platform constraint for this implementation.
  final TomPlatform platform;

  /// Creates an implementation info record.
  _TomImplementationInfo(this.classMirror, this.environment, this.platform);

  /// Finds the best matching implementation from a list of candidates.
  ///
  /// Selection priority (highest to lowest):
  /// 1. Exact match: both environment AND platform match
  /// 2. Platform match: platform matches, no environment constraint
  /// 3. Environment match: environment matches, no platform constraint
  /// 4. Default: no environment or platform constraints
  ///
  /// Each tier reuses the same single-winner scan ([_findSingleMatch]); only
  /// the candidate predicate differs. Returns null if no tier matches.
  ///
  /// The tiers are tried in order and the first one with a match wins, so a
  /// lower tier never overrides a higher one. A tier with *two* matches is an
  /// error rather than a reason to fall through — see [_findSingleMatch].
  static ClassMirror? _findImplementation(
    List<_TomImplementationInfo> infos,
    TomComponent tc,
  ) {
    // The active environment/platform are stable for the duration of one
    // resolution, so read them once rather than per candidate per tier.
    final env = _requireCurrentEnvironment(
      "implementation selection",
      tc.getType(),
    );
    final platform = TomRuntime.getCurrentPlatform();

    // Selectors are compared by name, never by instance — see
    // [_environmentMatches]. The two "unconstrained" tests below read the
    // sentinel the same way, so a component annotated with a literal
    // `TomEnvironment('none')` is treated as carrying no environment
    // constraint. That is the sentinel's name being reserved, which is what a
    // sentinel is for.
    return _findSingleMatch(
          infos,
          tc,
          (info) =>
              _environmentMatches(info.environment, env) &&
              _platformMatches(info.platform, platform),
          "platform and environment match",
        ) ??
        _findSingleMatch(
          infos,
          tc,
          (info) =>
              _platformMatches(info.platform, platform) &&
              _environmentMatches(info.environment, noTomEnvironment),
          "platform match",
        ) ??
        _findSingleMatch(
          infos,
          tc,
          (info) =>
              _environmentMatches(info.environment, env) &&
              _platformMatches(info.platform, noTomPlatform),
          "environment match",
        ) ??
        _findSingleMatch(
          infos,
          tc,
          (info) =>
              _environmentMatches(info.environment, noTomEnvironment) &&
              _platformMatches(info.platform, noTomPlatform),
          "default match without environment or platform",
        );
  }

  /// Returns the single candidate satisfying [matches], or null if none does.
  ///
  /// Throws [TomBeanLocatorException] when two candidates satisfy [matches]:
  /// within one tier the selectors carry no further information, so there is
  /// no principled way to prefer one over the other. Picking either would
  /// silently bind a deployment to an arbitrary implementation — the failure
  /// mode where the code runs, the tests pass, and production misbehaves. An
  /// ambiguous binding is a wiring bug, and it must surface as one.
  ///
  /// [matchDescription] names the tier for the trace log and the error.
  static ClassMirror? _findSingleMatch(
    List<_TomImplementationInfo> infos,
    TomComponent tc,
    bool Function(_TomImplementationInfo info) matches,
    String matchDescription,
  ) {
    ClassMirror? result;

    for (var info in infos) {
      if (!matches(info)) continue;
      if (result == null) {
        tomLog.trace(
          "Interface ${tc.getType()} $matchDescription "
          "for ${info.classMirror.qualifiedName}",
        );
        result = info.classMirror;
      } else {
        throw TomBeanLocatorException(
          "beanlocator.initialization.ambiguous_implementation",
          "Ambiguous implementation for ${tc.getType()}: both "
              "${result.qualifiedName} and ${info.classMirror.qualifiedName} "
              "qualify by $matchDescription. Distinguish them with a "
              "@TomEnvironment or @TomPlatform annotation, or remove one.",
          parameters: {
            "type": tc.getType(),
            "match": matchDescription,
            "first": result.qualifiedName,
            "second": info.classMirror.qualifiedName,
          },
          autoLog: true,
        );
      }
    }

    return result;
  }
}
