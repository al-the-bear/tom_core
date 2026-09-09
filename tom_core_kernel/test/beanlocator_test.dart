// ignore_for_file: unused_local_variable
import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'beanlocator_test.reflection.dart';

// ============================================================================
// Tests for the Tom Bean Locator System
// ============================================================================

// Test service interfaces
abstract class TestService {
  String doSomething();
}

class TestServiceImpl implements TestService {
  @override
  String doSomething() => 'done';
}

class AnotherService {
  String value;
  AnotherService(this.value);
}

// ----------------------------------------------------------------------------
// Ambiguous-type fixtures: two beans assignable to one interface.
// ----------------------------------------------------------------------------
abstract class AmbiguousService {}

class AmbiguousServiceA implements AmbiguousService {}

class AmbiguousServiceB implements AmbiguousService {}

// ----------------------------------------------------------------------------
// Reflection-discovered fixture: a concrete (@tomComponent / TomNoInterface)
// bean. This exercises initializeBeanContext -> _discoverAndInstantiateBeans
// -> _instantiateConcreteBean, registered under its runtime type.
//
// Interface-based discovery and the four-tier env/platform selection are
// covered by the dedicated selection suites, which need their own reflection
// domains: discovery walks *every* annotated class in the domain and is
// all-or-nothing, so a deliberately-unresolvable fixture would abort the pass
// for the fixtures around it. See beanlocator_selection_test.dart (the four
// tiers, precedence and the environment selector),
// beanlocator_ambiguous_selection_test.dart and
// beanlocator_excluded_selection_test.dart (the failure modes).
// ----------------------------------------------------------------------------

@tomReflector
@tomComponent
class DiscoveredConcreteService {
  String ping() => 'concrete';
}

/// A stand-in for [DiscoveredConcreteService], as a test would write one.
///
/// Deliberately *not* annotated: discovery must never find it on its own. An
/// annotated stub would be registered under its own runtime type as well, and
/// `TomBean<DiscoveredConcreteService>()` would then see two assignable
/// entries and fail as ambiguous — so the fixture would be testing the
/// ambiguity rule rather than the override.
class MockConcreteService extends DiscoveredConcreteService {
  @override
  String ping() => 'mock';
}

/// A concrete bean narrowed to one environment.
///
/// Discovery reads the active environment *only* for a class that carries
/// `@TomEnvironment`, so this is the fixture that reaches the runtime lookup on
/// the concrete path. It is the only class in this domain that does — no
/// `@TomComponent(SomeInterface)` fixture lives here (interface selection has
/// its own domains), so the concrete path is the only one that can reach the
/// runtime, and a failure in this file is unambiguously attributable to it.
@tomReflector
@tomComponent
@TomEnvironment('prod')
class EnvNarrowedConcreteService {
  String ping() => 'narrowed';
}

// ----------------------------------------------------------------------------
// Environment-selection fixtures: one interface, two environment-specific
// implementations. installByEnvironment must install exactly the one named by
// the active environment.
// ----------------------------------------------------------------------------
abstract class EnvBackend {
  String mode();
}

class LiveEnvBackend implements EnvBackend {
  @override
  String mode() => 'live';
}

class TestEnvBackend implements EnvBackend {
  @override
  String mode() => 'test';
}

void main() {
  // --------------------------------------------------------------------------
  // Setup
  // --------------------------------------------------------------------------
  setUpAll(() {
    initializeReflection();
  });

  setUp(() {
    // Isolate the process-global bean context between tests.
    TomBean.resetBeanContext();
    // …and the runtime with it. Environment selection reads process-global
    // state too, so a test that activates an environment would otherwise leave
    // it active for every test that follows — which is exactly how a suite
    // comes to depend on an environment none of its tests set.
    TomRuntime.reset();
  });

  /// Runs [body] and returns the `key` of the [TomBeanLocatorException] it
  /// throws, or a sentinel if it did not throw. Lets tests pin the *specific*
  /// error contract (which key), not merely that *some* exception was raised.
  String keyOfThrow(void Function() body) {
    try {
      body();
    } on TomBeanLocatorException catch (e) {
      return e.key;
    }
    return '<did-not-throw>';
  }

  /// Runs [body] and returns the [TomBeanLocatorException] it threw, or `null`
  /// if it completed. Where [keyOfThrow] pins which error was raised, this lets
  /// a test compare two raises to each other — same key *and* same parameters.
  TomBeanLocatorException? errorOfThrow(void Function() body) {
    try {
      body();
    } on TomBeanLocatorException catch (e) {
      return e;
    }
    return null;
  }

  // ==========================================================================
  // TomComponent Tests
  // ==========================================================================
  group('TomComponent', () {
    test('should create component with type', () {
      const component = TomComponent(String);

      expect(component.type, equals(String));
      expect(component.getType(), equals(String));
    });

    test('should have correct default tomComponent', () {
      expect(tomComponent.type, equals(TomNoInterface));
    });

    test('should have correct toString representation', () {
      const component = TomComponent(int);
      final str = component.toString();

      expect(str, contains('TomComponent'));
      expect(str, contains('int'));
    });
  });

  // ==========================================================================
  // TomBeanLocatorException Tests
  // ==========================================================================
  group('TomBeanLocatorException', () {
    test('should create exception with key and message', () {
      final exception = TomBeanLocatorException(
        'test.error.key',
        'Test error message',
      );

      expect(exception.key, equals('test.error.key'));
      expect(exception.defaultUserMessage, equals('Test error message'));
    });

    test('should create exception with parameters', () {
      final exception = TomBeanLocatorException(
        'test.error.key',
        'Error with params',
        parameters: {'name': 'test', 'value': 42},
      );

      expect(exception.parameters, isNotNull);
      expect(exception.parameters?['name'], equals('test'));
      expect(exception.parameters?['value'], equals(42));
    });
  });

  // ==========================================================================
  // Context reset hook
  // ==========================================================================
  group('resetBeanContext', () {
    test('clears registered beans so later lookups miss', () {
      TomBean.withName('ephemeral', AnotherService('gone'));
      expect(TomBean.getBeanByName('ephemeral'), isNotNull);

      TomBean.resetBeanContext();

      expect(TomBean.getBeanByName('ephemeral'), isNull);
    });
  });

  // ==========================================================================
  // TomBean Tests
  // ==========================================================================
  group('TomBean', () {
    group('Named Beans', () {
      test('withName should register a bean by name', () {
        final service = AnotherService('test-value');
        TomBean.withName('testBean1', service);

        final retrieved = TomBean.getBeanByName('testBean1');
        expect(retrieved, same(service));
      });

      test('fromName should create a handle to a named bean', () {
        final service = AnotherService('fromName-test');
        TomBean.withName('testBean2', service);

        final bean = TomBean<AnotherService>.fromName('testBean2');
        expect(bean.get(), same(service));
      });

      test('withName should throw for duplicate names', () {
        final service1 = AnotherService('first');
        final service2 = AnotherService('second');

        TomBean.withName('duplicateTest', service1);

        expect(
          () => TomBean.withName('duplicateTest', service2),
          throwsA(isA<TomBeanLocatorException>()),
        );
      });

      test('fromName resolves lazily when the bean is registered later', () {
        // A handle created before registration must still resolve once the
        // name is registered. The handle records the name unconditionally so
        // get() routes through name resolution.
        final bean = TomBean<AnotherService>.fromName('lazyBean');

        TomBean.withName('lazyBean', AnotherService('lazy-value'));

        expect(bean.get().value, equals('lazy-value'));
      });
    });

    group('Static Accessors', () {
      test('getBeanByName should return null for non-existent bean', () {
        final result = TomBean.getBeanByName('nonExistent');
        expect(result, isNull);
      });

      test('getBeanByType should return null for non-existent type', () {
        final result = TomBean.getBeanByType(DateTime);
        expect(result, isNull);
      });
    });

    group('Type Resolution', () {
      test('getType should return the type parameter', () {
        final bean = TomBean<AnotherService>();
        expect(bean.getType(), equals(AnotherService));
      });

      test('getBeanType should return the type parameter', () {
        final bean = TomBean<String>();
        expect(bean.getBeanType(), equals(String));
      });

      test('throws when more than one implementation matches the type', () {
        // Two beans assignable to AmbiguousService are registered under
        // distinct type keys; resolving by the shared interface must raise the
        // ambiguous-implementation error.
        TomBean.withType(AmbiguousServiceA, AmbiguousServiceA());
        TomBean.withType(AmbiguousServiceB, AmbiguousServiceB());

        expect(
          () => TomBean<AmbiguousService>().get(),
          throwsA(isA<TomBeanLocatorException>()),
        );
      });
    });

    group('Callable Syntax', () {
      test('should allow callable syntax with named beans', () {
        final service = AnotherService('callable-test');
        TomBean.withName('callableBean', service);

        final bean = TomBean<AnotherService>.fromName('callableBean');

        // Use callable syntax: bean() instead of bean.get()
        expect(bean().value, equals('callable-test'));
      });
    });

    group('withType', () {
      test('should register a bean by type', () {
        final service = AnotherService('type-test');
        // Use a unique type to avoid conflicts with other tests
        TomBean.withType(TestService, service);

        final retrieved = TomBean.getBeanByType(TestService);
        expect(retrieved, same(service));
      });

      test('should throw for duplicate types', () {
        TomBean.withType(TestService, AnotherService('first'));

        expect(
          () => TomBean.withType(TestService, AnotherService('second')),
          throwsA(isA<TomBeanLocatorException>()),
        );
      });
    });

    group('get resolution', () {
      test('should resolve bean by name when name is set', () {
        final service = AnotherService('named-resolution-unique');
        TomBean.withName('namedBeanUnique', service);

        final bean = TomBean<AnotherService>.fromName('namedBeanUnique');
        expect(bean.get(), same(service));
      });

      test('should throw when named bean type mismatch', () {
        final service = TestServiceImpl();
        TomBean.withName('typeMismatchBean', service);

        // Try to get it as the wrong type.
        final bean = TomBean<int>.fromName('typeMismatchBean');

        expect(() => bean.get(), throwsA(isA<TomBeanLocatorException>()));
      });
    });
  });

  // ==========================================================================
  // installByEnvironment: environment-selector dependency injection
  // ==========================================================================
  group('installByEnvironment', () {
    Map<String, EnvBackend Function()> factories() => {
      'prod': LiveEnvBackend.new,
      'test': TestEnvBackend.new,
    };

    test('installs the implementation named by the explicit environment', () {
      TomBean.installByEnvironment<EnvBackend>(
        factories(),
        environment: 'test',
      );

      expect(TomBean<EnvBackend>().get(), isA<TestEnvBackend>());
    });

    test('installs a single implementation, resolvable by interface', () {
      TomBean.installByEnvironment<EnvBackend>(
        factories(),
        environment: 'prod',
      );

      // One registration, resolved by the interface type — no dispatcher.
      expect(TomBean<EnvBackend>().get().mode(), equals('live'));
    });

    test('runs only the selected environment factory', () {
      var liveBuilt = false;
      var testBuilt = false;
      TomBean.installByEnvironment<EnvBackend>({
        'prod': () {
          liveBuilt = true;
          return LiveEnvBackend();
        },
        'test': () {
          testBuilt = true;
          return TestEnvBackend();
        },
      }, environment: 'test');

      expect(testBuilt, isTrue);
      expect(liveBuilt, isFalse, reason: 'unselected factory must not run');
    });

    test('reads the active environment from TomRuntime when none is given', () {
      TomRuntime.addEnvironment(const TomEnvironment('prod'));
      TomRuntime.setCurrentEnvironment('prod');

      TomBean.installByEnvironment<EnvBackend>(factories());

      expect(TomBean<EnvBackend>().get(), isA<LiveEnvBackend>());
    });

    test('throws when no factory matches the active environment', () {
      expect(
        () => TomBean.installByEnvironment<EnvBackend>(
          factories(),
          environment: 'staging',
        ),
        throwsA(isA<TomBeanLocatorException>()),
      );
    });
  });

  // ==========================================================================
  // Bean discovery via reflection (initializeBeanContext + four-tier selection)
  // ==========================================================================
  group('bean discovery', () {
    setUp(() {
      TomBean.resetBeanContext();
      // Discovery consults the active environment for every class carrying
      // @TomEnvironment, so the environment is part of this group's fixture,
      // not something it may inherit from whichever test ran before it.
      TomRuntime.addEnvironment(const TomEnvironment('prod'));
      TomRuntime.setCurrentEnvironment('prod');
      initializeBeanContext();
    });

    test('instantiates concrete @tomComponent beans by runtime type', () {
      final bean = TomBean.getBeanByType(DiscoveredConcreteService);
      expect(bean, isA<DiscoveredConcreteService>());
    });

    test('instantiates a concrete bean narrowed to the active environment', () {
      expect(
        TomBean.getBeanByType(EnvNarrowedConcreteService),
        isA<EnvNarrowedConcreteService>(),
      );
    });
  });

  // ==========================================================================
  // Selector matching on the concrete path: by name, not by instance
  // ==========================================================================
  group('concrete bean with a runtime-built environment', () {
    /// Builds an environment the way an application reading its name from
    /// configuration does.
    ///
    /// Because the name is a parameter the constructor cannot be `const`, so
    /// the result is a fresh instance rather than the canonicalised `const`
    /// that [EnvNarrowedConcreteService]'s annotation carries. Selection
    /// matches on the *name*, so where the instance came from must not matter
    /// — and `TomRuntime`'s own documented setup takes exactly this form.
    TomEnvironment environmentNamed(String name) => TomEnvironment(name);

    setUp(() {
      TomBean.resetBeanContext();
    });

    test('is bound when the runtime-built environment names its own', () {
      TomRuntime.addEnvironment(environmentNamed('prod'));
      TomRuntime.setCurrentEnvironment('prod');
      initializeBeanContext();

      expect(
        TomBean.getBeanByType(EnvNarrowedConcreteService),
        isA<EnvNarrowedConcreteService>(),
      );
    });

    test('is still discarded when the names differ', () {
      // Matching by name must not degrade into matching everything.
      TomRuntime.addEnvironment(environmentNamed('dev'));
      TomRuntime.setCurrentEnvironment('dev');
      initializeBeanContext();

      expect(TomBean.getBeanByType(EnvNarrowedConcreteService), isNull);
    });

    test('is bound when only the environment flags differ', () {
      // `isTest` and `isDevelopment` describe an environment; they do not
      // distinguish one. Two environments named 'prod' are one environment.
      TomRuntime.addEnvironment(
        const TomEnvironment('prod', isTest: true, isDevelopment: true),
      );
      TomRuntime.setCurrentEnvironment('prod');
      initializeBeanContext();

      expect(
        TomBean.getBeanByType(EnvNarrowedConcreteService),
        isA<EnvNarrowedConcreteService>(),
      );
    });
  });

  // ==========================================================================
  // Substituting an implementation: the route a test takes to inject a mock
  // ==========================================================================
  group('overriding a registered bean', () {
    // Registration is guarded: `withType` / `withName` refuse a key that is
    // already bound, which is what stops two unrelated startup paths from
    // silently clobbering each other. A test replacing a collaborator with a
    // mock wants exactly the opposite, so it says so — `overrideWithType` /
    // `overrideWithName` replace, and the guarded factories keep throwing.

    setUp(() {
      TomRuntime.addEnvironment(const TomEnvironment('prod'));
      TomRuntime.setCurrentEnvironment('prod');
    });

    test('overrideWithType replaces a binding discovery made', () {
      initializeBeanContext();
      expect(
        TomBean<DiscoveredConcreteService>().get().ping(),
        equals('concrete'),
      );

      TomBean.overrideWithType(
        DiscoveredConcreteService,
        MockConcreteService(),
      );

      expect(TomBean<DiscoveredConcreteService>().get().ping(), equals('mock'));
    });

    test('withType still refuses a type discovery already bound', () {
      initializeBeanContext();

      expect(
        keyOfThrow(
          () => TomBean.withType(
            DiscoveredConcreteService,
            MockConcreteService(),
          ),
        ),
        equals('beanlocator.initialization.duplicate_bean_with_type'),
        reason: 'the guard is the whole reason the override has to be named',
      );
    });

    test('a handle that already resolved keeps its instance', () {
      // get() caches, so a collaborator held as a field since before the
      // override still answers with the original. Overriding is a startup-time
      // move, not a live swap — the caveat is worth pinning because the failure
      // it produces is silent.
      initializeBeanContext();
      final resolved = TomBean<DiscoveredConcreteService>();
      expect(resolved.get().ping(), equals('concrete'));

      TomBean.overrideWithType(
        DiscoveredConcreteService,
        MockConcreteService(),
      );

      expect(resolved.get().ping(), equals('concrete'));
      expect(TomBean<DiscoveredConcreteService>().get().ping(), equals('mock'));
    });

    test('a concrete bean registered before discovery is not overwritten', () {
      // The other order: bind the stub first, then let the pass run. Discovery
      // must leave an occupied key alone — otherwise "register before
      // initializeBeanContext()" would work for interface components and fail,
      // silently, for concrete ones.
      TomBean.withType(DiscoveredConcreteService, MockConcreteService());

      initializeBeanContext();

      expect(TomBean<DiscoveredConcreteService>().get().ping(), equals('mock'));
    });

    test('re-initializing discards an override', () {
      // resetBeanContext + initializeBeanContext is what the testing guidance
      // puts in setUp, and it empties the registry — so an override has to be
      // re-applied after every pass, not merely applied once.
      initializeBeanContext();
      TomBean.overrideWithType(
        DiscoveredConcreteService,
        MockConcreteService(),
      );

      TomBean.resetBeanContext();
      initializeBeanContext();

      expect(
        TomBean<DiscoveredConcreteService>().get().ping(),
        equals('concrete'),
      );
    });

    test('re-initializing empties the named registry too', () {
      // `initializeBeanContext` rebuilds the wiring from scratch, and "from
      // scratch" has to mean both namespaces. Beans are held in two registries
      // — one keyed by `Type`, one by name — and a re-initialization that
      // emptied only the first would leave named beans from the previous pass
      // alive, which is the shape of leak the reset exists to prevent. The
      // typed half of the same rule is pinned by 're-initializing discards an
      // override' above; this is the half that has no other witness, because
      // nothing else in the module reads the two registries together.
      initializeBeanContext();
      TomBean.withName('survivor', AnotherService('first pass'));
      expect(TomBean.getBeanByName('survivor'), isNotNull);

      initializeBeanContext();

      expect(TomBean.getBeanByName('survivor'), isNull);
    });

    test('overrideWithName replaces a named binding', () {
      TomBean.withName('config', AnotherService('real'));

      TomBean.overrideWithName('config', AnotherService('stub'));

      expect(
        TomBean<AnotherService>.fromName('config').get().value,
        equals('stub'),
      );
    });

    test('withName still refuses a name already registered', () {
      TomBean.withName('config', AnotherService('real'));

      expect(
        keyOfThrow(() => TomBean.withName('config', AnotherService('stub'))),
        equals('beanlocator.initialization.duplicate_bean_with_name'),
      );
    });
  });

  // ==========================================================================
  // Startup validation: which pending handles initialization must vouch for
  // ==========================================================================
  group('startup validation', () {
    // initializeBeanContext resolves the handles constructed since the last
    // reset, so that a missing binding surfaces at boot rather than at the
    // first call that needed it. The question these tests pin is *which*
    // handles it can meaningfully vouch for.
    //
    // Discovery registers under `Type` keys only — a concrete bean under its
    // runtime type, an interface implementation under the interface. Nothing in
    // the pass ever registers a *name*; names enter the registry solely through
    // the imperative TomBean.withName. So a typed handle and a named handle are
    // not the same kind of promise: discovery is exactly what supplies the
    // former, and cannot supply the latter no matter what it discovers.

    setUp(() {
      // Discovery consults the active environment for this domain's
      // @TomEnvironment fixture, so the environment is part of the fixture.
      // Initialization is not — these tests choose when it runs.
      TomRuntime.addEnvironment(const TomEnvironment('prod'));
      TomRuntime.setCurrentEnvironment('prod');
    });

    test('an unsatisfiable typed handle fails initialization', () {
      // The fail-fast contract, unweakened: discovery is what would have
      // registered AnotherService, so a handle still unresolvable at the end of
      // the pass is a wiring bug and must be reported at boot.
      final orphan = TomBean<AnotherService>();

      expect(
        keyOfThrow(initializeBeanContext),
        equals('beanlocator.bean_access.no_bean_found_uninitialized'),
      );
    });

    test('a named handle awaiting its registration does not fail startup', () {
      // The "resolve before registration" pattern: hold the handle as a field
      // now, register the bean later in startup. Initialization must not
      // convert that into a boot failure — it cannot register the name itself,
      // so demanding the name be present is demanding something the pass has no
      // way to provide.
      final config = TomBean<AnotherService>.fromName('lateConfig');

      expect(keyOfThrow(initializeBeanContext), equals('<did-not-throw>'));

      TomBean.withName('lateConfig', AnotherService('late'));
      expect(
        config.get().value,
        equals('late'),
        reason:
            'the handle resolves once the registration lands, which is '
            'exactly why startup had no business failing on it',
      );
    });

    test(
      'a named handle registered with the wrong type still fails startup',
      () {
        // The skip is narrow: it covers "not registered yet", not "named
        // resolution is unchecked". Here the name *is* registered, so the
        // question is answerable at boot — and the answer is a type mismatch,
        // which no later registration will repair.
        TomBean.withName('wrongType', TestServiceImpl());
        final handle = TomBean<int>.fromName('wrongType');

        expect(
          keyOfThrow(initializeBeanContext),
          equals('beanlocator.bean_access.bean_not_found_by_type'),
        );
      },
    );

    test('a handle created after a pass is validated by the next one', () {
      // Validation must not depend on which side of an initializeBeanContext
      // call a handle happened to be constructed on. A handle created between
      // two passes is pending for the second one exactly as a handle created
      // before the first is pending for it.
      initializeBeanContext();

      final orphan = TomBean<AnotherService>();

      expect(
        keyOfThrow(initializeBeanContext),
        equals('beanlocator.bean_access.no_bean_found_uninitialized'),
        reason: 'a handle constructed between two passes was dropped unchecked',
      );
    });
  });

  // ==========================================================================
  // Unconfigured runtime: the locator's own exception, not the runtime's
  // ==========================================================================
  group('unconfigured runtime', () {
    // TomRuntime.getCurrentEnvironment throws a bare Exception when nothing has
    // been configured. That is tom_basics' contract, not the locator's: every
    // example and every line of this module's documentation teaches callers to
    // write `on TomBeanLocatorException`, and a bare Exception walks straight
    // past such a handler. Each locator entry point that reaches for the
    // environment must therefore translate the failure into its own contract,
    // and name what was being resolved when it happened.

    test('discovery raises the locator exception, naming the class', () {
      // The runtime is already pristine — the global setUp reset it.
      final failure = errorOfThrow(initializeBeanContext);

      expect(
        failure,
        isNotNull,
        reason: 'a bare Exception escaped the locator exception contract',
      );
      expect(
        failure!.key,
        equals('beanlocator.environment.runtime_environment_not_initialized'),
      );
      expect(
        failure.parameters?['subject'],
        contains('$EnvNarrowedConcreteService'),
        reason:
            'the failure must name the bean whose selector asked for the '
            'environment, not merely that some environment was missing',
      );
    });

    test(
      'installByEnvironment raises the locator exception, naming the type',
      () {
        final failure = errorOfThrow(
          () => TomBean.installByEnvironment<EnvBackend>({
            'prod': LiveEnvBackend.new,
          }),
        );

        expect(
          failure,
          isNotNull,
          reason: 'a bare Exception escaped the locator exception contract',
        );
        expect(
          failure!.key,
          equals('beanlocator.environment.runtime_environment_not_initialized'),
        );
        expect(failure.parameters?['subject'], equals('$EnvBackend'));
      },
    );

    test('an explicit environment needs no configured runtime', () {
      // The guard must only fire where the environment is actually consulted:
      // naming the environment at the call site answers the question the
      // runtime would have been asked.
      TomBean.installByEnvironment<EnvBackend>({
        'test': TestEnvBackend.new,
      }, environment: 'test');

      expect(TomBean<EnvBackend>().get(), isA<TestEnvBackend>());
    });
  });

  // ==========================================================================
  // Type resolution happy paths + caching
  // ==========================================================================
  group('type resolution', () {
    test('resolves a bean registered by type through its interface', () {
      TomBean.withType(TestService, TestServiceImpl());

      final resolved = TomBean<TestService>().get();

      expect(resolved, isA<TestServiceImpl>());
      expect(resolved.doSomething(), equals('done'));
    });

    test('callable syntax works on a type-resolved bean', () {
      TomBean.withType(TestService, TestServiceImpl());

      final bean = TomBean<TestService>();

      // bean() == bean.get() — resolve then call through.
      expect(bean().doSomething(), equals('done'));
    });

    test('caches the resolved instance on the handle', () {
      final service = AnotherService('cached');
      TomBean.withType(AnotherService, service);

      final bean = TomBean<AnotherService>();
      expect(identical(bean.get(), service), isTrue);

      // Wiping the global context does not un-resolve an already-resolved
      // handle: get() returns the cached instance without touching the context.
      TomBean.resetBeanContext();
      expect(identical(bean.get(), service), isTrue);
    });

    test(
      'throws no_bean_found_uninitialized when nothing matches the type',
      () {
        expect(
          keyOfThrow(() => TomBean<AnotherService>().get()),
          equals('beanlocator.bean_access.no_bean_found_uninitialized'),
        );
      },
    );

    test('a bean under a type it is not names both types', () {
      // `withType` takes its key as a `Type` *value*, and Dart has no
      // expression that decides whether an object is an instance of one, so
      // the registration below cannot be refused where it is made. Resolution
      // is the first point at which the relation is decidable, because there
      // `T` is a real type argument.
      //
      // Reporting it as an absence would be wrong twice over: the key *is*
      // bound, and "no bean found" sends the reader looking for a missing
      // registration rather than the wrong one sitting in front of them. That
      // is the failure this test exists for; a consumer in tom_core_server
      // already type-tests what it resolves rather than trust the key.
      TomBean.withType(TestService, AnotherService('not a TestService'));

      final error = errorOfThrow(() => TomBean<TestService>().get());
      expect(
        error?.key,
        equals('beanlocator.bean_access.bean_not_assignable_to_type'),
      );
      expect(
        error?.defaultUserMessage,
        allOf(contains('TestService'), contains('AnotherService')),
        reason: 'the type asked for and the type found, both named',
      );
    });

    test('a genuinely absent type still reports an absence', () {
      // The control. Without it the report above could widen to cover every
      // miss, and a missing registration would start reading as a mis-keyed
      // bean — trading one misdirection for another.
      expect(
        keyOfThrow(() => TomBean<TestService>().get()),
        equals('beanlocator.bean_access.no_bean_found_uninitialized'),
      );
    });

    test('a name and a type are two namespaces, not one lookup', () {
      // The registry is two maps — one keyed by `Type`, one by name — and
      // this is the contract that makes them two rather than an implementation
      // detail of how they are stored. A bean put in by name is reachable
      // *only* by that name; type resolution does not see it, even though the
      // instance would satisfy the type. The reverse holds as well.
      //
      // Worth pinning because it is invisible from either call site and would
      // survive being broken: merging the two lookups makes `withName` behave
      // like a second `withType` that also has a label, which silently changes
      // what an ambiguity means — two named beans of one type would start
      // reporting more_than_one_implementation_found for a type nobody
      // registered.
      TomBean.withName('by-name-only', AnotherService('named'));

      expect(
        keyOfThrow(() => TomBean<AnotherService>().get()),
        equals('beanlocator.bean_access.no_bean_found_uninitialized'),
        reason: 'a named bean is not a typed registration',
      );

      TomBean.resetBeanContext();
      TomBean.withType(AnotherService, AnotherService('typed'));

      expect(
        keyOfThrow(
          () => TomBean<AnotherService>.fromName('by-name-only').get(),
        ),
        equals('beanlocator.bean_access.bean_not_found_by_name'),
        reason: 'a typed bean is not reachable under an arbitrary name',
      );
    });
  });

  // ==========================================================================
  // Exception-key contract: each failure path raises its documented key.
  // ==========================================================================
  group('exception keys', () {
    test('duplicate named registration', () {
      TomBean.withName('dupKey', AnotherService('a'));
      expect(
        keyOfThrow(() => TomBean.withName('dupKey', AnotherService('b'))),
        equals('beanlocator.initialization.duplicate_bean_with_name'),
      );
    });

    test('duplicate typed registration', () {
      TomBean.withType(TestService, TestServiceImpl());
      expect(
        keyOfThrow(() => TomBean.withType(TestService, TestServiceImpl())),
        equals('beanlocator.initialization.duplicate_bean_with_type'),
      );
    });

    test('named lookup miss', () {
      expect(
        keyOfThrow(() => TomBean<AnotherService>.fromName('absent').get()),
        equals('beanlocator.bean_access.bean_not_found_by_name'),
      );
    });

    test('named lookup type mismatch', () {
      TomBean.withName('mismatch', TestServiceImpl());
      expect(
        keyOfThrow(() => TomBean<int>.fromName('mismatch').get()),
        equals('beanlocator.bean_access.bean_not_found_by_type'),
      );
    });

    test('ambiguous type resolution', () {
      TomBean.withType(AmbiguousServiceA, AmbiguousServiceA());
      TomBean.withType(AmbiguousServiceB, AmbiguousServiceB());
      expect(
        keyOfThrow(() => TomBean<AmbiguousService>().get()),
        equals('beanlocator.bean_access.more_than_one_implementation_found'),
      );
    });

    test('ambiguity is raised on every call, not only the first', () {
      // Ambiguity is an error, not a preference. A handle that reported it once
      // and then answered with whichever implementation the registry happened to
      // iterate first would be doing exactly the arbitrary resolution the error
      // exists to prevent — and it would do it silently, since the caller who
      // sees the answer is not the caller who saw the throw.
      TomBean.withType(AmbiguousServiceA, AmbiguousServiceA());
      TomBean.withType(AmbiguousServiceB, AmbiguousServiceB());

      final handle = TomBean<AmbiguousService>();
      final first = errorOfThrow(handle.get);
      final second = errorOfThrow(handle.get);

      expect(
        first?.key,
        equals('beanlocator.bean_access.more_than_one_implementation_found'),
      );
      expect(
        second,
        isNotNull,
        reason: 'the second get() resolved the ambiguity to an arbitrary bean',
      );
      expect(second!.key, equals(first!.key));
      expect(second.parameters, equals(first.parameters));

      // And it stays an error: no number of calls wears the ambiguity down.
      expect(
        errorOfThrow(handle.call)?.key,
        equals('beanlocator.bean_access.more_than_one_implementation_found'),
      );
    });

    test('installByEnvironment with no matching factory', () {
      expect(
        keyOfThrow(
          () => TomBean.installByEnvironment<EnvBackend>({
            'prod': LiveEnvBackend.new,
          }, environment: 'staging'),
        ),
        equals('beanlocator.environment.no_factory_for_environment'),
      );
    });
  });

  // ==========================================================================
  // installByEnvironment returns a usable handle
  // ==========================================================================
  group('installByEnvironment handle', () {
    test('the returned handle resolves the installed implementation', () {
      final handle = TomBean.installByEnvironment<EnvBackend>({
        'test': TestEnvBackend.new,
      }, environment: 'test');

      expect(handle.get(), isA<TestEnvBackend>());
      expect(handle().mode(), equals('test'));
    });
  });

  // ==========================================================================
  // TomBeanLocatorException Tests
  // ==========================================================================
  group('TomBeanLocatorException additional tests', () {
    test('should include root exception when provided', () {
      final rootException = FormatException('root cause');
      final exception = TomBeanLocatorException(
        'test.error.key',
        'Wrapped error',
        rootException: rootException,
      );

      expect(exception.rootException, isA<FormatException>());
    });

    test('should respect autoLog setting', () {
      final exception = TomBeanLocatorException(
        'test.error.key.autolog',
        'Auto-logged error',
        autoLog: true,
      );

      expect(exception.autoLog, isTrue);
    });

    test('should have stack trace captured automatically', () {
      final exception = TomBeanLocatorException(
        'test.error.key.stack',
        'Error with automatic stack',
      );

      expect(exception.stackTrace, isNotEmpty);
    });
  });
}
