/// Interface and Type Registration Example
///
/// This example demonstrates advanced bean registration patterns:
/// - Interface-based bean registration with @TomComponent(InterfaceType)
/// - Manual type-based registration with TomBean.withType()
/// - Static accessor methods: TomBean.getBeanByType() and TomBean.getBeanByName()
/// - Error handling with TomBeanLocatorException
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// ============================================================================
// Service Interfaces
// ============================================================================

/// A notification service interface.
abstract class NotificationService {
  void send(String message);
  String get lastMessage;
}

/// A metrics service interface.
abstract class MetricsService {
  void record(String metric, double value);
  Map<String, double> get metrics;
}

/// A cache interface.
abstract class CacheService {
  void put(String key, Object value);
  Object? get(String key);
  bool containsKey(String key);
}

// ============================================================================
// Service Implementations
// ============================================================================

/// Email notification implementation.
class EmailNotificationService implements NotificationService {
  String _lastMessage = '';

  @override
  void send(String message) {
    _lastMessage = message;
    print('     [EMAIL] $message');
  }

  @override
  String get lastMessage => _lastMessage;
}

/// Push notification implementation.
class PushNotificationService implements NotificationService {
  String _lastMessage = '';

  @override
  void send(String message) {
    _lastMessage = message;
    print('     [PUSH] $message');
  }

  @override
  String get lastMessage => _lastMessage;
}

/// In-memory metrics service.
class InMemoryMetricsService implements MetricsService {
  final Map<String, double> _metrics = {};

  @override
  void record(String metric, double value) {
    _metrics[metric] = value;
    print('     [METRIC] $metric = $value');
  }

  @override
  Map<String, double> get metrics => Map.unmodifiable(_metrics);
}

/// In-memory cache implementation.
class InMemoryCacheService implements CacheService {
  final Map<String, Object> _cache = {};

  @override
  void put(String key, Object value) {
    _cache[key] = value;
  }

  @override
  Object? get(String key) => _cache[key];

  @override
  bool containsKey(String key) => _cache.containsKey(key);
}

// ============================================================================
// Example Class
// ============================================================================

class InterfaceAndTypeRegistrationExample {
  // Captured results for assertions
  static late String registeredNotificationType;
  static late String resolvedNotificationMessage;
  static late String metricsServiceType;
  static late double recordedMetricValue;
  static bool caughtDuplicateTypeError = false;
  static late String caughtErrorKey;
  static bool getBeanByTypeWorks = false;
  static bool getBeanByNameWorks = false;
  static late String cacheServiceType;
  static bool caughtNotFoundError = false;

  // --------------------------------------------------------------------------
  // Example 1: Manual type-based registration with TomBean.withType()
  // --------------------------------------------------------------------------
  static void example1ManualTypeRegistration() {
    print('1. Manual type-based registration with TomBean.withType():');

    // Create a notification service instance
    final emailService = EmailNotificationService();

    // Register by interface type - this allows resolution by NotificationService
    TomBean.withType(NotificationService, emailService);
    registeredNotificationType = emailService.runtimeType.toString();

    print('   - Registered EmailNotificationService as NotificationService');
    print('   - Implementation type: $registeredNotificationType');

    // Now resolve using the interface type
    final resolvedService = TomBean<NotificationService>().get();
    resolvedService.send('Hello from manual registration!');
    resolvedNotificationMessage = resolvedService.lastMessage;

    print('   - Resolved service type: ${resolvedService.runtimeType}');
    print('   - Last message: $resolvedNotificationMessage');

    // Assertions
    assert(
      resolvedService is EmailNotificationService,
      'Should resolve to EmailNotificationService',
    );
    assert(
      resolvedNotificationMessage == 'Hello from manual registration!',
      'Message should match',
    );
    assert(
      identical(emailService, resolvedService),
      'Should be the same instance',
    );
  }

  // --------------------------------------------------------------------------
  // Example 2: Using static accessor TomBean.getBeanByType()
  // --------------------------------------------------------------------------
  static void example2GetBeanByType() {
    print('\n2. Static accessor TomBean.getBeanByType():');

    // Register a metrics service by type
    final metricsService = InMemoryMetricsService();
    TomBean.withType(MetricsService, metricsService);

    // Use static accessor to retrieve bean
    final retrieved = TomBean.getBeanByType(MetricsService);
    metricsServiceType = retrieved?.runtimeType.toString() ?? 'null';

    print('   - Retrieved bean type: $metricsServiceType');

    if (retrieved != null && retrieved is MetricsService) {
      retrieved.record('cpu_usage', 45.5);
      recordedMetricValue = retrieved.metrics['cpu_usage'] ?? 0;
      getBeanByTypeWorks = true;
    }

    print('   - Recorded metric value: $recordedMetricValue');
    print('   - getBeanByType() works: $getBeanByTypeWorks');

    // Assertions
    assert(getBeanByTypeWorks, 'getBeanByType should work');
    assert(recordedMetricValue == 45.5, 'Metric value should be 45.5');
  }

  // --------------------------------------------------------------------------
  // Example 3: Using static accessor TomBean.getBeanByName()
  // --------------------------------------------------------------------------
  static void example3GetBeanByName() {
    print('\n3. Static accessor TomBean.getBeanByName():');

    // Register beans by name
    final pushService = PushNotificationService();
    TomBean.withName('type_reg_pushNotifier', pushService);

    // Use static accessor to retrieve bean
    final retrieved = TomBean.getBeanByName('type_reg_pushNotifier');

    if (retrieved != null && retrieved is NotificationService) {
      retrieved.send('Push notification test');
      getBeanByNameWorks = true;
      print('   - Retrieved bean type: ${retrieved.runtimeType}');
      print('   - Message sent successfully');
    }

    // Also test that non-existent name returns null
    final nonExistent = TomBean.getBeanByName('type_reg_nonExistent');
    print('   - Non-existent bean returns: $nonExistent');

    // Assertions
    assert(getBeanByNameWorks, 'getBeanByName should work');
    assert(nonExistent == null, 'Non-existent should return null');
  }

  // --------------------------------------------------------------------------
  // Example 4: Duplicate type registration error
  // --------------------------------------------------------------------------
  static void example4DuplicateTypeError() {
    print('\n4. Duplicate type registration throws TomBeanLocatorException:');

    // Create a new cache service
    final cacheService = InMemoryCacheService();
    
    // First registration succeeds
    TomBean.withType(CacheService, cacheService);
    cacheServiceType = 'CacheService registered';
    print('   - First registration of CacheService: success');

    // Second registration of same type should throw
    try {
      final anotherCache = InMemoryCacheService();
      TomBean.withType(CacheService, anotherCache);
      print('   - ERROR: Should have thrown exception');
    } on TomBeanLocatorException catch (e) {
      caughtDuplicateTypeError = true;
      caughtErrorKey = e.key;
      print('   - Caught TomBeanLocatorException');
      print('   - Error key: ${e.key}');
      print('   - Message: ${e.defaultUserMessage}');
    }

    // Assertions
    assert(
      caughtDuplicateTypeError,
      'Should catch duplicate type exception',
    );
    assert(
      caughtErrorKey == 'beanlocator.initialization.duplicate_bean_with_type',
      'Error key should match',
    );
  }

  // --------------------------------------------------------------------------
  // Example 5: Bean not found error handling
  // --------------------------------------------------------------------------
  static void example5BeanNotFoundError() {
    print('\n5. Bean not found error handling:');

    // Try to resolve a non-existent bean type
    try {
      // This interface was never registered
      final bean = TomBean<_NonExistentService>()..get();
      print('   - ERROR: Should have thrown exception, got: $bean');
    } on TomBeanLocatorException catch (e) {
      caughtNotFoundError = true;
      print('   - Caught TomBeanLocatorException for unregistered type');
      print('   - Error key: ${e.key}');
      print('   - Parameters: ${e.parameters}');
    }

    // Assertions
    assert(caughtNotFoundError, 'Should catch not found exception');
  }

  // --------------------------------------------------------------------------
  // Example 6: TomBean callable syntax comparison
  // --------------------------------------------------------------------------
  static void example6CallableSyntax() {
    print('\n6. TomBean callable syntax - () vs .get():');

    // Both syntaxes are equivalent
    final bean1 = TomBean<NotificationService>();
    final bean2 = TomBean<NotificationService>();

    // Using .get()
    final service1 = bean1.get();

    // Using callable ()
    final service2 = bean2();

    // They should resolve to the same instance
    final areSame = identical(service1, service2);
    print('   - bean.get() returns: ${service1.runtimeType}');
    print('   - bean() returns: ${service2.runtimeType}');
    print('   - Both return same instance: $areSame');

    // Chain method calls with callable syntax
    bean1().send('Chained with .get()');
    bean2().send('Chained with ()');

    print('   - Method chaining works with both syntaxes');

    // Assertions
    assert(areSame, 'Both syntaxes should return same instance');
    assert(
      service1.lastMessage == 'Chained with ()',
      'Last message should be from second call',
    );
  }

  // --------------------------------------------------------------------------
  // Example 7: getType() and getBeanType() methods
  // --------------------------------------------------------------------------
  static void example7TypeMethods() {
    print('\n7. TomBean type inspection methods:');

    final bean = TomBean<NotificationService>();
    
    // getType() returns the type parameter T
    final declaredType = bean.getType();
    
    // getBeanType() also returns T (alias for getType)
    final beanType = bean.getBeanType();

    print('   - getType() returns: $declaredType');
    print('   - getBeanType() returns: $beanType');
    print('   - Types are equal: ${declaredType == beanType}');

    // After resolution, we can compare declared type vs actual type
    final resolved = bean.get();
    final actualType = resolved.runtimeType;

    print('   - Declared type (interface): $declaredType');
    print('   - Actual type (implementation): $actualType');

    // Assertions
    assert(declaredType == NotificationService, 'getType should return NotificationService');
    assert(beanType == NotificationService, 'getBeanType should return NotificationService');
    assert(actualType == EmailNotificationService, 'Actual type should be implementation');
  }

  // --------------------------------------------------------------------------
  // Example 8: TomComponent marker classes
  // --------------------------------------------------------------------------
  static void example8MarkerClasses() {
    print('\n8. TomComponent marker classes:');

    // TomComponent annotation holds the interface type
    const component = TomComponent(NotificationService);
    final componentType = component.getType();

    print('   - TomComponent for NotificationService');
    print('   - getType() returns: $componentType');
    print('   - toString(): $component');

    // tomComponent is the default for concrete types (TomNoInterface)
    const defaultComponent = tomComponent;
    final defaultType = defaultComponent.getType();

    print('   - Default tomComponent type: $defaultType');
    print('   - Is TomNoInterface: ${defaultType == TomNoInterface}');

    // Assertions
    assert(componentType == NotificationService, 'Component type should match');
    assert(defaultType == TomNoInterface, 'Default should be TomNoInterface');
  }
}

// Private interface for testing non-existent bean resolution
abstract class _NonExistentService {
  void doSomething();
}

// ============================================================================
// Run Function
// ============================================================================

void run() {
  print('═══════════════════════════════════════════════════════════════════');
  print('INTERFACE AND TYPE REGISTRATION EXAMPLE');
  print('═══════════════════════════════════════════════════════════════════\n');

  InterfaceAndTypeRegistrationExample.example1ManualTypeRegistration();
  InterfaceAndTypeRegistrationExample.example2GetBeanByType();
  InterfaceAndTypeRegistrationExample.example3GetBeanByName();
  InterfaceAndTypeRegistrationExample.example4DuplicateTypeError();
  InterfaceAndTypeRegistrationExample.example5BeanNotFoundError();
  InterfaceAndTypeRegistrationExample.example6CallableSyntax();
  InterfaceAndTypeRegistrationExample.example7TypeMethods();
  InterfaceAndTypeRegistrationExample.example8MarkerClasses();

  print('\n✓ All interface and type registration examples passed!\n');
}

void main() => run();
