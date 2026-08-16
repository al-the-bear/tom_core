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

import 'dart:core';

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
/// - `beanlocator.initialization.duplicate_bean_with_name`: Duplicate named bean
/// - `beanlocator.bean_access.bean_not_found_by_name`: Named bean not found
/// - `beanlocator.bean_access.bean_not_found_by_type`: Type mismatch for named bean
/// - `beanlocator.bean_access.no_bean_found_uninitialized`: Unresolved bean
/// - `beanlocator.initialization.no_matching_implementation_found`: No implementation
/// - `beanlocator.initialization.ambiguous_implementation`: Two implementations
///   qualify equally for one interface
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
  /// The global bean context mapping types/names to instances.
  static final Map<Object, Object> _tomBeanContext = {};

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
  factory TomBean.fromName(String name) {
    TomBean<T> result = TomBean();
    // Record the name unconditionally so that get() always routes through
    // _resolveByName, even when the bean is registered after this handle is
    // created (lazy named resolution). Pre-caching the instance is only an
    // optimisation for the already-registered case.
    result._name = name;
    Object? bean = _tomBeanContext[name];
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
    TomBean<T> result = TomBean();
    result._bean = bean as T;
    result._name = name;

    if (_tomBeanContext[name] != null) {
      throw TomBeanLocatorException(
        "beanlocator.initialization.duplicate_bean_with_name",
        "Duplicate bean with name $name",
        parameters: {"name": name},
        autoLog: true,
      );
    }

    _tomBeanContext[name] = bean;
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
  /// Note: This will take precedence over any @TomComponent registrations for the same type.
  /// This is useful for testing or if environment/platform-specific selection is not desired or
  /// cannot be expressed via annotations.
  factory TomBean.withType(Type t, Object bean) {
    TomBean<T> result = TomBean();
    result._bean = bean as T;

    if (_tomBeanContext[t] != null) {
      throw TomBeanLocatorException(
        "beanlocator.initialization.duplicate_bean_with_type",
        "Duplicate bean with type $t",
        parameters: {"type": t},
        autoLog: true,
      );
    }

    _tomBeanContext[t] = bean;
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
  /// fallback.
  static TomBean<T> installByEnvironment<T>(
    Map<String, T Function()> factories, {
    String? environment,
  }) {
    final env = environment ?? TomRuntime.getCurrentEnvironment().env;
    final factory = factories[env];
    if (factory == null) {
      throw TomBeanLocatorException(
        "beanlocator.environment.no_factory_for_environment",
        "No bean factory registered for environment '$env'.",
        parameters: {
          "environment": env,
          "available": factories.keys.toList(),
        },
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
    return _tomBeanContext[type];
  }

  /// Returns the bean registered with [name], or null if not found.
  static Object? getBeanByName(String name) {
    return _tomBeanContext[name];
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
    _tomBeanContext.clear();
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
    var obj = _tomBeanContext[_name];

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
      for (var serviceType in _tomBeanContext.keys) {
        if (serviceType is! Type) continue;
        final candidate = _tomBeanContext[serviceType]!;
        if (_assignableFrom(candidate)) {
          matches.add(MapEntry(serviceType, candidate as T));
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

  /// Returns the bean type [T].
  Type getBeanType() {
    return T;
  }
}

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
/// 1. Clear any existing context if re-initializing
/// 2. Discover annotated classes via reflection
/// 3. Filter by environment and platform constraints
/// 4. Instantiate and register beans
/// 5. Validate all TomBean references
///
/// ## Usage
///
/// ```dart
/// // Set up environment first
/// TomRuntime.setCurrentEnvironment("dev");
/// TomRuntime.initializePlatform();
///
/// // Then initialize beans
/// initializeBeanContext();
///
/// // Now beans can be resolved
/// final service = TomBean<MyService>().get();
/// ```
void initializeBeanContext() {
  if (TomBean._initialized) {
    TomBean._tomBeanContext.clear();
    TomBean._tomBeanList.clear();
  }

  _discoverAndInstantiateBeans();
  _validateBeanReferences();

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

  // Check environment constraint
  for (var meta in classMirror.metadata) {
    if (meta is TomEnvironment &&
        meta.env != TomRuntime.getCurrentEnvironment().env) {
      tomLog.trace(
        "Discarding service class $classMirror because environments don't match.",
      );
      return;
    }
    if (meta is TomPlatform &&
        meta.name != TomRuntime.getCurrentPlatform()?.name) {
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
  TomBean._tomBeanContext[obj.runtimeType] = obj;
}

/// Instantiates a bean that implements an interface.
void _instantiateInterfaceBean(ClassMirror classMirror, TomComponent tc) {
  if (TomBean._tomBeanContext[tc.getType()] != null) {
    tomLog.trace(
      "Service Instance for ${tc.getType()} already assigned to "
      "${TomBean._tomBeanContext[tc.getType()]}",
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
    TomBean._tomBeanContext[tc.getType()] = obj;
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

/// Validates all bean references by resolving them.
void _validateBeanReferences() {
  for (var bean in TomBean._tomBeanList) {
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
    final env = TomRuntime.getCurrentEnvironment();
    final platform = TomRuntime.getCurrentPlatform();

    return _findSingleMatch(
          infos,
          tc,
          (info) => info.environment == env && info.platform == platform,
          "platform and environment match",
        ) ??
        _findSingleMatch(
          infos,
          tc,
          (info) =>
              info.platform == platform && info.environment == noTomEnvironment,
          "platform match",
        ) ??
        _findSingleMatch(
          infos,
          tc,
          (info) =>
              info.environment == env && info.platform == noTomPlatform,
          "environment match",
        ) ??
        _findSingleMatch(
          infos,
          tc,
          (info) =>
              info.environment == noTomEnvironment &&
              info.platform == noTomPlatform,
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
