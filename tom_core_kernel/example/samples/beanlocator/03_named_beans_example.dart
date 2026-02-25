/// Named Beans Example
///
/// This example shows how to register beans by name using TomBean.withName
/// and resolve them using TomBean.fromName.
///
/// Key patterns:
/// - Registering beans with unique names
/// - Resolving beans by name
/// - Multiple beans of the same type with different names
/// - Static bean access methods
/// - Callable syntax: bean() vs bean.get()
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// ============================================================================
// Configuration Classes
// ============================================================================

/// A database configuration holder.
class DatabaseConfig {
  final String host;
  final int port;
  final String database;
  final bool isPrimary;

  DatabaseConfig({
    required this.host,
    required this.port,
    required this.database,
    this.isPrimary = false,
  });

  @override
  String toString() => 'DatabaseConfig($host:$port/$database, primary: $isPrimary)';
}

/// An API endpoint configuration.
class ApiEndpointConfig {
  final String baseUrl;
  final String apiKey;
  final Duration timeout;

  ApiEndpointConfig({
    required this.baseUrl,
    required this.apiKey,
    this.timeout = const Duration(seconds: 30),
  });

  @override
  String toString() => 'ApiEndpointConfig($baseUrl, timeout: ${timeout.inSeconds}s)';
}

/// A cache configuration.
class CacheConfig {
  final int maxSize;
  final Duration ttl;

  CacheConfig({required this.maxSize, required this.ttl});

  @override
  String toString() => 'CacheConfig(maxSize: $maxSize, ttl: ${ttl.inMinutes}min)';
}

// ============================================================================
// Example Class
// ============================================================================

class NamedBeansExample {
  // Captured results
  static late String primaryHost;
  static late String replicaHost;
  static late List<String> apiEndpoints;
  static bool sameInstance = false;
  static late String caughtErrorKey;

  // -------------------------------------------------------------------------
  // Example 1: Registering named beans
  // -------------------------------------------------------------------------
  static void example1RegisteringNamedBeans() {
    print('1. Registering named beans:');

    // Create and register database configurations
    final primaryDb = DatabaseConfig(
      host: 'primary.db.example.com',
      port: 5432,
      database: 'app_primary',
      isPrimary: true,
    );

    final replicaDb = DatabaseConfig(
      host: 'replica.db.example.com',
      port: 5432,
      database: 'app_replica',
      isPrimary: false,
    );

    // Register with unique names
    TomBean.withName('named_primaryDb', primaryDb);
    TomBean.withName('named_replicaDb', replicaDb);

    print('   - Registered "named_primaryDb": $primaryDb');
    print('   - Registered "named_replicaDb": $replicaDb');

    // Assertions
    assert(primaryDb.isPrimary == true, 'Primary should be marked as primary');
    assert(replicaDb.isPrimary == false, 'Replica should not be primary');
  }

  // -------------------------------------------------------------------------
  // Example 2: Resolving named beans
  // -------------------------------------------------------------------------
  static void example2ResolvingNamedBeans() {
    print('\n2. Resolving named beans with TomBean.fromName:');

    // Resolve the beans by name
    final resolvedPrimary = TomBean<DatabaseConfig>.fromName('named_primaryDb');
    final resolvedReplica = TomBean<DatabaseConfig>.fromName('named_replicaDb');

    // Use callable syntax to access the bean
    final primaryConfig = resolvedPrimary();
    final replicaConfig = resolvedReplica();

    primaryHost = primaryConfig.host;
    replicaHost = replicaConfig.host;

    print('   - Retrieved primary host: $primaryHost');
    print('   - Retrieved replica host: $replicaHost');
    print('   - Primary is primary? ${primaryConfig.isPrimary}');
    print('   - Replica is primary? ${replicaConfig.isPrimary}');

    // Assertions
    assert(primaryHost == 'primary.db.example.com', 'Primary host should match');
    assert(replicaHost == 'replica.db.example.com', 'Replica host should match');
    assert(primaryConfig.isPrimary == true, 'Primary should be marked as primary');
  }

  // -------------------------------------------------------------------------
  // Example 3: Multiple beans of the same type
  // -------------------------------------------------------------------------
  static void example3MultipleSameType() {
    print('\n3. Multiple beans of the same type with different names:');

    // Register multiple API endpoints
    final internalApi = ApiEndpointConfig(
      baseUrl: 'https://internal-api.example.com',
      apiKey: 'internal-key-123',
      timeout: const Duration(seconds: 10),
    );

    final externalApi = ApiEndpointConfig(
      baseUrl: 'https://external-api.example.com',
      apiKey: 'external-key-456',
      timeout: const Duration(seconds: 60),
    );

    final partnerApi = ApiEndpointConfig(
      baseUrl: 'https://partner-api.example.com',
      apiKey: 'partner-key-789',
      timeout: const Duration(seconds: 45),
    );

    TomBean.withName('named_internalApi', internalApi);
    TomBean.withName('named_externalApi', externalApi);
    TomBean.withName('named_partnerApi', partnerApi);

    // Resolve each by name
    final internalEndpoint = TomBean<ApiEndpointConfig>.fromName('named_internalApi')();
    final externalEndpoint = TomBean<ApiEndpointConfig>.fromName('named_externalApi')();
    final partnerEndpoint = TomBean<ApiEndpointConfig>.fromName('named_partnerApi')();

    apiEndpoints = [
      internalEndpoint.baseUrl,
      externalEndpoint.baseUrl,
      partnerEndpoint.baseUrl,
    ];

    print('   - Internal API: ${internalEndpoint.baseUrl}');
    print('   - External API: ${externalEndpoint.baseUrl}');
    print('   - Partner API: ${partnerEndpoint.baseUrl}');

    // Assertions
    assert(apiEndpoints.length == 3, 'Should have 3 endpoints');
    assert(apiEndpoints[0].contains('internal'), 'First should be internal');
  }

  // -------------------------------------------------------------------------
  // Example 4: Static bean access methods
  // -------------------------------------------------------------------------
  static void example4StaticAccess() {
    print('\n4. Static bean access methods:');

    // Get by name using static method
    final byNameResult = TomBean.getBeanByName('named_primaryDb');
    print('   - TomBean.getBeanByName("named_primaryDb"):');
    print('     Type: ${byNameResult.runtimeType}');
    print('     Value: $byNameResult');

    // Get by type
    final byTypeResult = TomBean.getBeanByType(DatabaseConfig);
    print('   - TomBean.getBeanByType(DatabaseConfig):');
    print('     Type: ${byTypeResult?.runtimeType}');

    // Assertions
    assert(byNameResult is DatabaseConfig, 'Should be DatabaseConfig');
    assert(byTypeResult != null, 'Should find bean by type');
  }

  // -------------------------------------------------------------------------
  // Example 5: Using .get() vs callable syntax
  // -------------------------------------------------------------------------
  static void example5GetVsCallable() {
    print('\n5. Accessing beans: .get() vs callable syntax:');

    final cacheConfig = CacheConfig(
      maxSize: 1000,
      ttl: const Duration(minutes: 15),
    );
    final cacheBean = TomBean.withName('named_cache', cacheConfig);

    // Both access the same bean
    final viaGet = cacheBean.get();
    final viaCallable = cacheBean();

    sameInstance = identical(viaGet, viaCallable);

    print('   - Using .get(): $viaGet');
    print('   - Using (): $viaCallable');
    print('   - Same instance? $sameInstance');

    // Assertions
    assert(sameInstance, 'Should be the same instance');
  }

  // -------------------------------------------------------------------------
  // Example 6: Error handling for missing beans
  // -------------------------------------------------------------------------
  static void example6ErrorHandling() {
    print('\n6. Error handling for missing beans:');

    caughtErrorKey = '';

    try {
      TomBean<DatabaseConfig>.fromName('nonexistent_db_config').get();
    } on TomBeanLocatorException catch (e) {
      caughtErrorKey = e.key;
      print('   - Exception type: TomBeanLocatorException');
      print('   - Error key: $caughtErrorKey');
      print('   - Message contains bean name: ${e.defaultUserMessage.contains('nonexistent_db_config')}');
    }

    // Assertions
    assert(caughtErrorKey.isNotEmpty, 'Should catch exception');
    assert(caughtErrorKey.contains('beanlocator'), 'Error key should contain beanlocator');
  }

  // -------------------------------------------------------------------------
  // Example 7: Bean reference identity
  // -------------------------------------------------------------------------
  static void example7BeanReferenceIdentity() {
    print('\n7. Bean reference identity:');

    // Get the same bean twice
    final ref1 = TomBean<DatabaseConfig>.fromName('named_primaryDb');
    final ref2 = TomBean<DatabaseConfig>.fromName('named_primaryDb');

    // They should return the same underlying object
    final obj1 = ref1();
    final obj2 = ref2();

    final identicalObjects = identical(obj1, obj2);

    print('   - ref1(): ${obj1.host}');
    print('   - ref2(): ${obj2.host}');
    print('   - Same object? $identicalObjects');

    // Assertions
    assert(identicalObjects, 'Should return the same object');
  }

  // -------------------------------------------------------------------------
  // Run all examples
  // -------------------------------------------------------------------------
  static void run() {
    print('=== 03: Named Beans Example ===\n');

    example1RegisteringNamedBeans();
    example2ResolvingNamedBeans();
    example3MultipleSameType();
    example4StaticAccess();
    example5GetVsCallable();
    example6ErrorHandling();
    example7BeanReferenceIdentity();

    print('\n=== Named Beans Example Complete ===\n');
  }
}

void run() => NamedBeansExample.run();

void main() => run();
