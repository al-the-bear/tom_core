/// Configuration Resource Provider Example
///
/// This example demonstrates TomConfigResourceProvider for managing
/// application configuration values.
///
/// Key concepts:
/// - Creating configuration providers from maps
/// - Using loader functions to build a provider from a computed map
/// - Hierarchical key access with dot notation
/// - Typed configuration values (int, bool, nested objects), and why they are
///   read through `getObjectOrNull` rather than a direct `getObject` cast
/// - Environment-specific configuration
///
/// Every provider here is a local instance. The application-wide singleton —
/// `setAppConfigProvider` / `getAppConfig`, the static `loader`, and the
/// independence of the text and config singletons — belongs to example 04.
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/resources/02_config_resource_provider_example.dart
/// ```
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

// ============================================================================
// Example Class
// ============================================================================

class ConfigResourceProviderExample {
  // Captured results
  static late String apiBaseUrl;
  static late int timeout;
  static late bool darkModeEnabled;
  static late bool analyticsExists;
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

    // Access configuration values.
    //
    // `getObjectOrNull` rather than `getObject` for the non-String values:
    // `getObject` echoes the key back as a `String` when the key is absent, so
    // `as int` throws on a miss (and so does `as int?`). `getObjectOrNull`
    // returns null on a miss, which `?? default` then absorbs. See example 3.
    apiBaseUrl = config.getObjectOrNull('api.baseUrl') as String? ?? '';
    timeout = config.getObjectOrNull('api.timeout') as int? ?? 5000;
    darkModeEnabled =
        config.getObjectOrNull('features.darkMode') as bool? ?? false;
    maxItems = config.getObjectOrNull('features.maxItems') as int? ?? 20;

    print('   - API Base URL: $apiBaseUrl');
    print('   - Timeout: $timeout ms');
    print('   - Dark mode enabled: $darkModeEnabled');
    print('   - Max items: $maxItems');
    print('   - Simple key: ${config.getObject('simpleKey')}');

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
    final existingValue = config.getObject('existing');
    final missingValue = config.getObject('missing.key.path');

    print('   - Existing key returns: $existingValue');
    print('   - Missing key returns: $missingValue (the key itself)');

    // This is useful for development - you can easily spot missing config
    final debugMessage = 'Config value: ${config.getObject('debug.level')}';
    print('   - Debug message shows key: $debugMessage');

    // The sharp edge of that fallback: the echoed key is a String, so casting
    // a missing value to the type you expected throws — and a *nullable* cast
    // throws just the same, because the echoed key is non-null.
    final typed = TomConfigResourceProvider.from({
      'api': {'timeout': 30000},
    });
    var directCastThrew = false;
    try {
      // ignore: unused_local_variable
      final retries = typed.getObject('api.retries') as int;
    } on TypeError {
      directCastThrew = true;
    }
    print(
      '   - getObject(...) as int on a missing key threw: $directCastThrew',
    );

    // Two ways to read a typed value without that risk. Prefer the first: one
    // lookup, one line, and it cannot throw on an absent key.
    final retries = typed.getObjectOrNull('api.retries') as int? ?? 3;
    final timeoutMs = typed.exists('api.timeout')
        ? typed.getObject('api.timeout') as int
        : 5000;

    print('   - Retries (absent, defaulted): $retries');
    print('   - Timeout (present): $timeoutMs ms');

    // Assertions
    assert(existingValue == 'value', 'Existing should return value');
    assert(missingValue == 'missing.key.path', 'Missing should return key');
    assert(directCastThrew, 'A direct cast of a missing key should throw');
    assert(retries == 3, 'Absent config should fall back to the default');
    assert(timeoutMs == 30000, 'Present config should win over the default');
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
    final dbHost = config.getObject('database.host');
    final dbPort = config.getObject('database.port');
    final cacheTtl = config.getObject('cache.ttl');

    print('   - Database host: $dbHost');
    print('   - Database port: $dbPort');
    print('   - Cache TTL: $cacheTtl seconds');

    // Assertions
    assert(dbHost == 'localhost', 'DB host should be localhost');
    assert(dbPort == 5432, 'DB port should be 5432');
    assert(cacheTtl == 3600, 'Cache TTL should be 3600');
  }

  // --------------------------------------------------------------------------
  // Example 5: Environment-specific configuration pattern
  // --------------------------------------------------------------------------
  static void example5EnvironmentConfig() {
    print('\n5. Environment-specific configuration pattern:');

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

    devApiUrl = devConfig.getObject('api.baseUrl') as String;
    prodApiUrl = prodConfig.getObject('api.baseUrl') as String;

    print('   - Dev API URL: $devApiUrl');
    print('   - Dev debug: ${devConfig.getObject('api.debug')}');
    print('   - Prod API URL: $prodApiUrl');
    print('   - Prod debug: ${prodConfig.getObject('api.debug')}');

    // Assertions
    assert(devApiUrl.contains('localhost'), 'Dev should use localhost');
    assert(prodApiUrl.contains('api.example.com'), 'Prod should use real API');
    assert(devConfig.getObject('api.debug') == true, 'Dev should have debug');
    assert(
      prodConfig.getObject('api.debug') == false,
      'Prod should not have debug',
    );
  }

  // --------------------------------------------------------------------------
  // Example 6: Accessing nested configuration
  // --------------------------------------------------------------------------
  static void example6NestedConfig() {
    print('\n6. Accessing nested configuration:');

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
    final primaryHost = config.getObject('database.primary.host');
    final primaryUsername = config.getObject(
      'database.primary.credentials.username',
    );
    final replicaPort = config.getObject('database.replica.port');

    print('   - Primary host: $primaryHost');
    print('   - Primary username: $primaryUsername');
    print('   - Replica port: $replicaPort');

    // Access entire nested object
    final primaryCredentials = config.getObject('database.primary.credentials');
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
  // Example 7: Configuration with lists
  // --------------------------------------------------------------------------
  static void example7ListConfig() {
    print('\n7. Configuration with lists:');

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
    final origins = config.getObject('allowedOrigins');
    final enabledFlags = config.getObject('features.enabledFlags');
    final rateLimits = config.getObject('limits.rateLimits');

    print('   - Allowed origins: $origins');
    print('   - Enabled flags: $enabledFlags');
    print('   - Rate limits: $rateLimits');

    // Work with lists.
    //
    // Dot notation stops at a list: a segment descends only into a Map with
    // String keys, so 'allowedOrigins.0' is not an index — it is a path that
    // cannot be resolved, and the miss is silent (the key comes back as its own
    // text, like any other miss). Fetching the list whole and indexing it in
    // Dart is not a stylistic choice here; it is the only way in.
    assert(
      config.getObject('allowedOrigins.0') == 'allowedOrigins.0',
      'Dotted paths do not index lists — the key is echoed back',
    );
    assert(
      config.getObject('limits.rateLimits.0.endpoint') ==
          'limits.rateLimits.0.endpoint',
      'This holds at any depth past the list',
    );

    if (origins is List) {
      print('   - First origin: ${origins[0]}');
      print('   - Origins count: ${origins.length}');
    }

    // The same applies to the list of maps: read it whole, then index.
    final firstRateLimit = (rateLimits as List).first as Map;
    print('   - First rate limit endpoint: ${firstRateLimit['endpoint']}');

    // Assertions
    assert(origins is List, 'Origins should be a List');
    assert((origins as List).length == 3, 'Should have 3 origins');
    assert(
      firstRateLimit['endpoint'] == '/api/users',
      'Indexing in Dart reaches what the dotted path could not',
    );
  }
}

// ============================================================================
// Run Function
// ============================================================================

void run() {
  print('=== 02: Configuration Resource Provider Example ===\n');

  ConfigResourceProviderExample.example1CreateFromMap();
  ConfigResourceProviderExample.example2ExistsCheck();
  ConfigResourceProviderExample.example3FallbackBehavior();
  ConfigResourceProviderExample.example4LoaderFunction();
  ConfigResourceProviderExample.example5EnvironmentConfig();
  ConfigResourceProviderExample.example6NestedConfig();
  ConfigResourceProviderExample.example7ListConfig();

  print('\n✓ All configuration resource provider examples passed!\n');
}

/// Standalone entry point.
void main() {
  prepareSampleProcess();
  run();
}
