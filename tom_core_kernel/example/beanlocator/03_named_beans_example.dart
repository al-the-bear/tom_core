/// Demonstrates named bean registration and resolution with executable code.
///
/// This example shows how to register beans by name using TomBean.withName
/// and resolve them using TomBean.fromName.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// ============================================================================
// Example Configuration Classes
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
  String toString() =>
      'DatabaseConfig($host:$port/$database, primary: $isPrimary)';
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

void run() {
  print('=== 03: Named Beans Example ===\n');

  // -------------------------------------------------------------------------
  // Example 1: Registering named beans
  // -------------------------------------------------------------------------
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

  // Register with unique names for this example
  TomBean.withName('ex3_primaryDb', primaryDb);
  TomBean.withName('ex3_replicaDb', replicaDb);

  print('   - Registered "ex3_primaryDb": $primaryDb');
  print('   - Registered "ex3_replicaDb": $replicaDb');

  // -------------------------------------------------------------------------
  // Example 2: Resolving named beans
  // -------------------------------------------------------------------------
  print('\n2. Resolving named beans with TomBean.fromName:');

  // Resolve the beans by name
  final resolvedPrimary = TomBean<DatabaseConfig>.fromName('ex3_primaryDb');
  final resolvedReplica = TomBean<DatabaseConfig>.fromName('ex3_replicaDb');

  // Use callable syntax to access the bean
  final primaryConfig = resolvedPrimary();
  final replicaConfig = resolvedReplica();

  print('   - Retrieved primary host: ${primaryConfig.host}');
  print('   - Retrieved replica host: ${replicaConfig.host}');
  print('   - Primary is primary? ${primaryConfig.isPrimary}');
  print('   - Replica is primary? ${replicaConfig.isPrimary}');

  // -------------------------------------------------------------------------
  // Example 3: Multiple beans of the same type
  // -------------------------------------------------------------------------
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

  TomBean.withName('ex3_internalApi', internalApi);
  TomBean.withName('ex3_externalApi', externalApi);
  TomBean.withName('ex3_partnerApi', partnerApi);

  // Resolve each by name
  final internalEndpoint = TomBean<ApiEndpointConfig>.fromName('ex3_internalApi')();
  final externalEndpoint = TomBean<ApiEndpointConfig>.fromName('ex3_externalApi')();
  final partnerEndpoint = TomBean<ApiEndpointConfig>.fromName('ex3_partnerApi')();

  print('   - Internal API: ${internalEndpoint.baseUrl}');
  print('   - External API: ${externalEndpoint.baseUrl}');
  print('   - Partner API: ${partnerEndpoint.baseUrl}');

  // -------------------------------------------------------------------------
  // Example 4: Static bean access methods
  // -------------------------------------------------------------------------
  print('\n4. Static bean access methods:');

  // Get by name using static method
  final byNameResult = TomBean.getBeanByName('ex3_primaryDb');
  print('   - TomBean.getBeanByName("ex3_primaryDb"):');
  print('     Type: ${byNameResult.runtimeType}');
  print('     Value: $byNameResult');

  // Get by type. Named registration does not populate the type index, so we
  // also register the primary instance under its type to demonstrate the
  // type accessor returning a live value.
  TomBean.withType(DatabaseConfig, primaryDb);
  final byTypeResult = TomBean.getBeanByType(DatabaseConfig);
  print('   - TomBean.getBeanByType(DatabaseConfig):');
  print('     Type: ${byTypeResult?.runtimeType}');

  // -------------------------------------------------------------------------
  // Example 5: Using .get() vs callable syntax
  // -------------------------------------------------------------------------
  print('\n5. Accessing beans: .get() vs callable syntax:');

  final cacheConfig = CacheConfig(
    maxSize: 1000,
    ttl: const Duration(minutes: 15),
  );
  final cacheBean = TomBean.withName('ex3_cache', cacheConfig);

  // Both access the same bean
  final viaGet = cacheBean.get();
  final viaCallable = cacheBean();

  print('   - Using .get(): $viaGet');
  print('   - Using (): $viaCallable');
  print('   - Same instance? ${identical(viaGet, viaCallable)}');

  // -------------------------------------------------------------------------
  // Example 6: Error handling for missing beans
  // -------------------------------------------------------------------------
  print('\n6. Error handling for missing beans:');

  String caughtKey = '';
  String caughtMessage = '';

  try {
    TomBean<DatabaseConfig>.fromName('nonexistent_db_config').get();
  } on TomBeanLocatorException catch (e) {
    caughtKey = e.key;
    caughtMessage = e.defaultUserMessage;
    print('   - Exception type: TomBeanLocatorException');
    print('   - Error key: $caughtKey');
    print('   - Message contains bean name: ${caughtMessage.contains("nonexistent_db_config")}');
  }

  // -------------------------------------------------------------------------
  // Example 7: Checking if a bean exists
  // -------------------------------------------------------------------------
  print('\n7. Checking if a bean exists:');

  final existingBean = TomBean.getBeanByName('ex3_primaryDb');
  final missingBean = TomBean.getBeanByName('definitely_does_not_exist');

  print('   - "ex3_primaryDb" exists? ${existingBean != null}');
  print('   - "definitely_does_not_exist" exists? ${missingBean != null}');

  final existsCheck = existingBean != null;
  final missingCheck = missingBean == null;

  print('\n');

  // =========================================================================
  // Assertions
  // =========================================================================

  // Example 1: Registration
  assert(primaryDb.host == 'primary.db.example.com');
  assert(replicaDb.host == 'replica.db.example.com');

  // Example 2: Resolution
  assert(primaryConfig.isPrimary == true);
  assert(replicaConfig.isPrimary == false);
  assert(identical(primaryConfig, primaryDb), 'Should be same instance');

  // Example 3: Multiple beans of same type
  assert(internalEndpoint.timeout.inSeconds == 10);
  assert(externalEndpoint.timeout.inSeconds == 60);
  assert(partnerEndpoint.timeout.inSeconds == 45);

  // Example 4: Static access
  assert(byNameResult is DatabaseConfig);
  assert(byTypeResult != null);

  // Example 5: Access methods
  assert(identical(viaGet, viaCallable));

  // Example 6: Error handling. A *named* lookup miss raises the by-name key
  // (an unnamed/type lookup miss would instead raise no_bean_found_uninitialized).
  assert(caughtKey == 'beanlocator.bean_access.bean_not_found_by_name');
  assert(caughtMessage.contains('DatabaseConfig'));

  // Example 7: Existence check
  assert(existsCheck == true);
  assert(missingCheck == true);
}
