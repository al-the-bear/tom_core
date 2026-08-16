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
// Ambiguous-type fixtures (bug §1): two beans assignable to one interface.
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
        // Bug §2 regression: a handle created before registration must still
        // resolve once the name is registered. The handle records the name
        // unconditionally so get() routes through name resolution.
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
        // Bug §1 regression: two beans assignable to AmbiguousService are
        // registered under distinct type keys; resolving by the shared
        // interface must raise the ambiguous-implementation error.
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

        expect(
          () => bean.get(),
          throwsA(isA<TomBeanLocatorException>()),
        );
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
      TomBean.installByEnvironment<EnvBackend>(
        {
          'prod': () {
            liveBuilt = true;
            return LiveEnvBackend();
          },
          'test': () {
            testBuilt = true;
            return TestEnvBackend();
          },
        },
        environment: 'test',
      );

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
      initializeBeanContext();
    });

    test('instantiates concrete @tomComponent beans by runtime type', () {
      final bean = TomBean.getBeanByType(DiscoveredConcreteService);
      expect(bean, isA<DiscoveredConcreteService>());
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

    test('throws no_bean_found_uninitialized when nothing matches the type', () {
      expect(
        keyOfThrow(() => TomBean<AnotherService>().get()),
        equals('beanlocator.bean_access.no_bean_found_uninitialized'),
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
          () => TomBean.installByEnvironment<EnvBackend>(
            {'prod': LiveEnvBackend.new},
            environment: 'staging',
          ),
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
      final handle = TomBean.installByEnvironment<EnvBackend>(
        {'test': TestEnvBackend.new},
        environment: 'test',
      );

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
