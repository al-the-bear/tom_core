// ignore_for_file: unused_local_variable
import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

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

void main() {
  // --------------------------------------------------------------------------
  // Setup
  // --------------------------------------------------------------------------
  setUp(() {
    // Reset runtime state between tests
    // Note: In a real application, you'd have a reset method
  });

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

      // Note: duplicate type test removed because static context persists between tests
    });

    group('get resolution', () {
      test('should resolve bean by name when name is set', () {
        final service = AnotherService('named-resolution-unique');
        TomBean.withName('namedBeanUnique', service);

        final bean = TomBean<AnotherService>.fromName('namedBeanUnique');
        expect(bean.get(), same(service));
      });

      test('should throw when named bean type mismatch', () {
        final uniqueName = 'typeMismatchBean_${DateTime.now().microsecondsSinceEpoch}';
        final service = TestServiceImpl();
        TomBean.withName(uniqueName, service);

        // Try to get it as wrong type
        final bean = TomBean<int>.fromName(uniqueName);

        expect(
          () => bean.get(),
          throwsA(isA<TomBeanLocatorException>()),
        );
      });
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
