/// Configuration Resource Provider Example
///
/// This example demonstrates TomConfigResourceProvider for managing
/// application configuration values.
///
/// Key concepts:
/// - Creating configuration providers from maps
/// - Using loader functions to build a provider from a computed map
/// - Hierarchical key access with dot notation
/// - Typed configuration values (int, bool, nested objects)
/// - Global singleton pattern
/// - Environment-specific configuration
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_asserts.dart';

// ============================================================================
// Example Class
// ============================================================================

class ConfigResourceProviderExample {
  // Captured results
  static late String apiBaseUrl;
  static late int timeout;
  static late bool darkModeEnabled;
  static late bool analyticsExists;
  static bool globalConfigWorks = false;
  static late String devApiUrl;
  static late String prodApiUrl;
  static late int maxItems;

  // --------------------------------------------------------------------------
  // Example 1: Creating TomConfigResourceProvider from map
  // --------------------------------------------------------------------------
  static void example1CreateFromMap() {
    print('1. Creating TomConfigResourceProvider from map:');

    // Create a config provider directly from a map
    final config = TomConfigResourceProvider.from({
      'api': {
        'baseUrl': 'https://api.example.com',
        'timeout': 30000,
        'retryCount': 3,
      },
      'features': {'darkMode': true, 'analytics': false, 'maxItems': 100},
      'simpleKey': 'simple value',
    });

    // Access configuration values
    apiBaseUrl = config.getText('api.baseUrl') as String;
    timeout = config.getText('api.timeout') as int;
    darkModeEnabled = config.getText('features.darkMode') as bool;
    maxItems = config.getText('features.maxItems') as int;

    print('   - API Base URL: $apiBaseUrl');
    print('   - Timeout: $timeout ms');
    print('   - Dark mode enabled: $darkModeEnabled');
    print('   - Max items: $maxItems');
    print('   - Simple key: ${config.getText('simpleKey')}');

    // Assertions
    assert(apiBaseUrl == 'https://api.example.com', 'API URL should match');
    assert(timeout == 30000, 'Timeout should be 30000');
    assert(darkModeEnabled == true, 'Dark mode should be enabled');
    assert(maxItems == 100, 'Max items should be 100');
  }

  // --------------------------------------------------------------------------
  // Example 2: Checking configuration existence
  // --------------------------------------------------------------------------
  static void example2ExistsCheck() {
    print('\n2. Checking configuration existence:');

    final config = TomConfigResourceProvider.from({
      'api': {'baseUrl': 'https://api.example.com'},
      'features': {'analytics': true},
    });

    // Check if configuration keys exist
    final apiExists = config.exists('api.baseUrl');
    analyticsExists = config.exists('features.analytics');
    final experimentalExists = config.exists('features.experimental');
    final unknownExists = config.exists('completely.unknown.path');

    print('   - api.baseUrl exists: $apiExists');
    print('   - features.analytics exists: $analyticsExists');
    print('   - features.experimental exists: $experimentalExists');
    print('   - unknown.path exists: $unknownExists');

    // Assertions
    assert(apiExists == true, 'API base URL should exist');
    assert(analyticsExists == true, 'Analytics should exist');
    assert(experimentalExists == false, 'Experimental should not exist');
    assert(unknownExists == false, 'Unknown path should not exist');
  }

  // --------------------------------------------------------------------------
  // Example 3: Missing key fallback behavior
  // --------------------------------------------------------------------------
  static void example3FallbackBehavior() {
    print('\n3. Missing key fallback behavior:');

    final config = TomConfigResourceProvider.from({'existing': 'value'});

    // Missing keys return the key itself
    final existingValue = config.getText('existing');
    final missingValue = config.getText('missing.key.path');

    print('   - Existing key returns: $existingValue');
    print('   - Missing key returns: $missingValue (the key itself)');

    // This is useful for development - you can easily spot missing config
    final debugMessage = 'Config value: ${config.getText('debug.level')}';
    print('   - Debug message shows key: $debugMessage');

    // Assertions
    assert(existingValue == 'value', 'Existing should return value');
    assert(missingValue == 'missing.key.path', 'Missing should return key');
  }

  // --------------------------------------------------------------------------
  // Example 4: Using a loader function to build the map
  // --------------------------------------------------------------------------
  static void example4LoaderFunction() {
    print('\n4. Using a loader function to build the map:');

    // Create provider with a loader function
    final config = TomConfigResourceProvider.load(() {
      // This could load from a file, network, etc.
      print('   - Loader function called!');
      return {
        'database': {'host': 'localhost', 'port': 5432, 'name': 'myapp_db'},
        'cache': {'enabled': true, 'ttl': 3600},
      };
    });

    // Access configuration
    final dbHost = config.getText('database.host');
    final dbPort = config.getText('database.port');
    final cacheTtl = config.getText('cache.ttl');

    print('   - Database host: $dbHost');
    print('   - Database port: $dbPort');
    print('   - Cache TTL: $cacheTtl seconds');

    // Assertions
    assert(dbHost == 'localhost', 'DB host should be localhost');
    assert(dbPort == 5432, 'DB port should be 5432');
    assert(cacheTtl == 3600, 'Cache TTL should be 3600');
  }

  // --------------------------------------------------------------------------
  // Example 5: Global singleton pattern
  // --------------------------------------------------------------------------
  static void example5GlobalSingleton() {
    print('\n5. Global singleton pattern:');

    // Set the global configuration provider
    TomConfigResourceProvider.setAppConfigProvider(
      TomConfigResourceProvider.from({
        'app': {'name': 'My Application', 'version': '2.0.0'},
        'settings': {'theme': 'dark', 'language': 'en'},
      }),
    );

    // Access from anywhere using getAppConfig()
    final globalConfig = TomConfigResourceProvider.getAppConfig();
    final appName = globalConfig.getText('app.name');
    final theme = globalConfig.getText('settings.theme');

    globalConfigWorks = appName == 'My Application';

    print('   - App name from global: $appName');
    print('   - Theme from global: $theme');

    // Multiple calls return the same instance
    final sameConfig = TomConfigResourceProvider.getAppConfig();
    final isSameInstance = identical(globalConfig, sameConfig);
    print('   - Same singleton instance: $isSameInstance');

    // Assertions
    assert(globalConfigWorks, 'Global config should work');
    assert(isSameInstance, 'Should be same instance');
  }

  // --------------------------------------------------------------------------
  // Example 6: Environment-specific configuration pattern
  // --------------------------------------------------------------------------
  static void example6EnvironmentConfig() {
    print('\n6. Environment-specific configuration pattern:');

    // Factory function for environment-specific config
    TomConfigResourceProvider createConfigForEnv(String env) {
      final configs = {
        'dev': {
          'api': {
            'baseUrl': 'http://localhost:8080',
            'debug': true,
            'mockData': true,
          },
          'logging': {'level': 'debug'},
        },
        'int': {
          'api': {
            'baseUrl': 'https://int.api.example.com',
            'debug': true,
            'mockData': false,
          },
          'logging': {'level': 'info'},
        },
        'prod': {
          'api': {
            'baseUrl': 'https://api.example.com',
            'debug': false,
            'mockData': false,
          },
          'logging': {'level': 'warn'},
        },
      };

      return TomConfigResourceProvider.from(configs[env] ?? configs['dev']!);
    }

    // Create configs for different environments
    final devConfig = createConfigForEnv('dev');
    final prodConfig = createConfigForEnv('prod');

    devApiUrl = devConfig.getText('api.baseUrl') as String;
    prodApiUrl = prodConfig.getText('api.baseUrl') as String;

    print('   - Dev API URL: $devApiUrl');
    print('   - Dev debug: ${devConfig.getText('api.debug')}');
    print('   - Prod API URL: $prodApiUrl');
    print('   - Prod debug: ${prodConfig.getText('api.debug')}');

    // Assertions
    assert(devApiUrl.contains('localhost'), 'Dev should use localhost');
    assert(prodApiUrl.contains('api.example.com'), 'Prod should use real API');
    assert(devConfig.getText('api.debug') == true, 'Dev should have debug');
    assert(
      prodConfig.getText('api.debug') == false,
      'Prod should not have debug',
    );
  }

  // --------------------------------------------------------------------------
  // Example 7: Accessing nested configuration
  // --------------------------------------------------------------------------
  static void example7NestedConfig() {
    print('\n7. Accessing nested configuration:');

    final config = TomConfigResourceProvider.from({
      'database': {
        'primary': {
          'host': 'primary.db.example.com',
          'port': 5432,
          'credentials': {'username': 'admin', 'password': 'secret'},
        },
        'replica': {'host': 'replica.db.example.com', 'port': 5433},
      },
    });

    // Deep nested access
    final primaryHost = config.getText('database.primary.host');
    final primaryUsername = config.getText(
      'database.primary.credentials.username',
    );
    final replicaPort = config.getText('database.replica.port');

    print('   - Primary host: $primaryHost');
    print('   - Primary username: $primaryUsername');
    print('   - Replica port: $replicaPort');

    // Access entire nested object
    final primaryCredentials = config.getText('database.primary.credentials');
    print('   - Credentials object type: ${primaryCredentials.runtimeType}');
    if (primaryCredentials is Map) {
      print('   - Credentials map: $primaryCredentials');
    }

    // Assertions
    assert(
      primaryHost == 'primary.db.example.com',
      'Primary host should match',
    );
    assert(primaryUsername == 'admin', 'Username should be admin');
    assert(replicaPort == 5433, 'Replica port should be 5433');
  }

  // --------------------------------------------------------------------------
  // Example 8: Configuration with lists
  // --------------------------------------------------------------------------
  static void example8ListConfig() {
    print('\n8. Configuration with lists:');

    final config = TomConfigResourceProvider.from({
      'allowedOrigins': [
        'https://example.com',
        'https://app.example.com',
        'http://localhost:3000',
      ],
      'features': {
        'enabledFlags': ['feature_a', 'feature_b', 'feature_c'],
        'disabledFlags': ['feature_x'],
      },
      'limits': {
        'rateLimits': [
          {'endpoint': '/api/users', 'limit': 100},
          {'endpoint': '/api/orders', 'limit': 50},
        ],
      },
    });

    // Access list configuration
    final origins = config.getText('allowedOrigins');
    final enabledFlags = config.getText('features.enabledFlags');
    final rateLimits = config.getText('limits.rateLimits');

    print('   - Allowed origins: $origins');
    print('   - Enabled flags: $enabledFlags');
    print('   - Rate limits: $rateLimits');

    // Work with lists
    if (origins is List) {
      print('   - First origin: ${origins[0]}');
      print('   - Origins count: ${origins.length}');
    }

    // Assertions
    assert(origins is List, 'Origins should be a List');
    assert((origins as List).length == 3, 'Should have 3 origins');
  }
}

// ============================================================================
// Run Function
// ============================================================================

void run() {
  print('═══════════════════════════════════════════════════════════════════');
  print('CONFIGURATION RESOURCE PROVIDER EXAMPLE');
  print(
    '═══════════════════════════════════════════════════════════════════\n',
  );

  ConfigResourceProviderExample.example1CreateFromMap();
  ConfigResourceProviderExample.example2ExistsCheck();
  ConfigResourceProviderExample.example3FallbackBehavior();
  ConfigResourceProviderExample.example4LoaderFunction();
  ConfigResourceProviderExample.example5GlobalSingleton();
  ConfigResourceProviderExample.example6EnvironmentConfig();
  ConfigResourceProviderExample.example7NestedConfig();
  ConfigResourceProviderExample.example8ListConfig();

  print('\n✓ All configuration resource provider examples passed!\n');
}

void main() {
  requireAsserts();
  run();
}
