/// Demonstrates JSON navigation and manipulation utilities including
/// deep merging, tree traversal, path-based access, and JSON sanitization.
///
/// This example covers:
/// - Deep merging of nested map structures (mergeMapsOneSided)
/// - Tree traversal with string processing (traverseAndProcess)
/// - Path-based access to nested values (getPathFromTree, getObjectFromTree)
/// - JSON sanitization for serialization (makeCleanJsonMap)
///
/// These utilities are particularly useful for:
/// - Configuration management with environment-specific overrides
/// - Template variable expansion in configuration trees
/// - Navigating complex nested JSON structures
/// - Preparing maps for JSON serialization
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

void run() {
  print('=== 02: JSON Navigation Example ===\n');

  // ===========================================================================
  // Example 1: Basic Map Merging
  // ===========================================================================

  print('1. Basic deep merge of configuration maps:');

  // Note: nested maps must be typed as Map<String, Object> for merge to work
  final baseConfig = <String, dynamic>{
    'database': <String, Object>{'host': 'localhost', 'port': 5432},
    'cache': <String, Object>{'enabled': false},
  };
  final overrideConfig = <String, dynamic>{
    'database': <String, Object>{'host': 'production.db.com'},
    'cache': <String, Object>{'enabled': true, 'ttl': 3600},
  };

  print('   Base config: $baseConfig');
  print('   Override config: $overrideConfig');

  mergeMapsOneSided(baseConfig, overrideConfig);

  final mergedHost = baseConfig['database']['host'] as String;
  final mergedPort = baseConfig['database']['port'] as int;
  final mergedCacheEnabled = baseConfig['cache']['enabled'] as bool;
  final mergedCacheTtl = baseConfig['cache']['ttl'] as int;

  print('   After merge:');
  print('   - database.host: $mergedHost (overridden)');
  print('   - database.port: $mergedPort (preserved)');
  print('   - cache.enabled: $mergedCacheEnabled (overridden)');
  print('   - cache.ttl: $mergedCacheTtl (added)');
  print('');

  // ===========================================================================
  // Example 2: Merging with Arrays
  // ===========================================================================

  print('2. Deep merge with array handling:');

  final baseWithArray = <String, dynamic>{
    'features': ['auth', 'logging'],
    'servers': [
      <String, Object>{'name': 'primary', 'port': 8080},
    ],
  };
  final overrideWithArray = <String, dynamic>{
    'features': ['auth', 'logging', 'metrics', 'tracing'],
  };

  print('   Base features: ${baseWithArray['features']}');
  print('   Override features: ${overrideWithArray['features']}');

  mergeMapsOneSided(baseWithArray, overrideWithArray);

  final mergedFeatures = baseWithArray['features'] as List;
  final featuresCount = mergedFeatures.length;

  print('   Merged features: $mergedFeatures');
  print('   Total features count: $featuresCount');
  print('');

  // ===========================================================================
  // Example 3: Tree Traversal with String Processing
  // ===========================================================================

  print('3. Tree traversal with variable substitution:');

  final templateConfig = <String, Object>{
    'api': {
      'baseUrl': r'${BASE_URL}/api/v1',
      'healthCheck': r'${BASE_URL}/health',
    },
    'static': {'assets': r'${CDN_URL}/assets'},
    'name': 'MyApplication',
  };

  print('   Before processing:');
  print('   - api.baseUrl: ${templateConfig['api']}');
  print('   - static.assets: ${templateConfig['static']}');

  traverseAndProcess(
    templateConfig,
    (s) => s.contains(r'${'),
    (s) => s
        .replaceAll(r'${BASE_URL}', 'https://api.example.com')
        .replaceAll(r'${CDN_URL}', 'https://cdn.example.com'),
  );

  final processedApiBaseUrl =
      (templateConfig['api'] as Map<String, Object>)['baseUrl'] as String;
  final processedHealthCheck =
      (templateConfig['api'] as Map<String, Object>)['healthCheck'] as String;
  final processedAssets =
      (templateConfig['static'] as Map<String, Object>)['assets'] as String;
  final unchangedName = templateConfig['name'] as String;

  print('   After processing:');
  print('   - api.baseUrl: $processedApiBaseUrl');
  print('   - api.healthCheck: $processedHealthCheck');
  print('   - static.assets: $processedAssets');
  print('   - name: $unchangedName (unchanged, no template)');
  print('');

  // ===========================================================================
  // Example 4: Path-Based Tree Access
  // ===========================================================================

  print('4. Path-based access to nested values:');

  final deepConfig = <String, dynamic>{
    'services': {
      'database': {
        'primary': {'host': 'db1.example.com', 'port': 5432},
        'replica': {'host': 'db2.example.com', 'port': 5432},
      },
      'cache': {
        'redis': {'host': 'redis.example.com', 'port': 6379},
      },
    },
  };

  final primaryDb = getPathFromTree(
    deepConfig,
    'services.database.primary',
    'result',
  );
  final primaryHost = primaryDb['host'] as String;
  final primaryPort = primaryDb['port'] as int;

  print('   Config tree structure: services -> database -> primary/replica');
  print('   Path: services.database.primary');
  print('   - host: $primaryHost');
  print('   - port: $primaryPort');
  print('');

  // ===========================================================================
  // Example 5: Getting Objects from Tree Paths
  // ===========================================================================

  print('5. Getting specific values from nested paths:');

  final redisHost = getObjectFromTree(deepConfig, 'services.cache.redis.host');
  final redisPort = getObjectFromTree(deepConfig, 'services.cache.redis.port');
  final replicaConfig = getObjectFromTree(
    deepConfig,
    'services.database.replica',
  );

  print('   services.cache.redis.host: $redisHost');
  print('   services.cache.redis.port: $redisPort');
  print('   services.database.replica (full object): $replicaConfig');
  print('');

  // ===========================================================================
  // Example 6: JSON Map Sanitization
  // ===========================================================================

  print('6. Cleaning maps for JSON serialization:');

  final dirtyMap = <dynamic, dynamic>{
    'name': 'TestApp',
    'version': 1.5,
    'active': true,
    'count': 42,
    123: 'numeric key (will be filtered)',
    'metadata': {
      'created': 'timestamp here',
      'nested': {'valid': 'data'},
    },
    'tags': ['alpha', 'beta', 'gamma'],
  };

  print('   Original map has ${dirtyMap.length} entries');
  print('   Includes non-string key: 123');

  final cleanMap = makeCleanJsonMap(dirtyMap);
  final cleanMapKeys = cleanMap.keys.toList();

  print('   Cleaned map has ${cleanMap.length} entries');
  print('   Clean keys: $cleanMapKeys');
  print('   - name: ${cleanMap['name']}');
  print('   - version: ${cleanMap['version']}');
  print('   - active: ${cleanMap['active']}');
  print('   - tags: ${cleanMap['tags']}');
  print('');

  // ===========================================================================
  // Example 7: Nested List Cleaning
  // ===========================================================================

  print('7. Cleaning nested structures with lists:');

  final nestedDirty = <String, dynamic>{
    'items': [
      {'id': 1, 'name': 'First'},
      {'id': 2, 'name': 'Second'},
    ],
    'matrix': [
      [1, 2, 3],
      [4, 5, 6],
    ],
  };

  final nestedClean = makeCleanJsonMap(nestedDirty);
  final cleanedItems = nestedClean['items'] as List;
  final cleanedMatrix = nestedClean['matrix'] as List;

  print('   Items cleaned: $cleanedItems');
  print('   Matrix cleaned: $cleanedMatrix');
  print('   First item id: ${(cleanedItems[0] as Map)['id']}');
  print('   Matrix[0][0]: ${(cleanedMatrix[0] as List)[0]}');
  print('');

  // ===========================================================================
  // Assertions
  // ===========================================================================

  // Example 1: Basic map merging
  assert(mergedHost == 'production.db.com'); // Overridden value
  assert(mergedPort == 5432); // Preserved from base
  assert(mergedCacheEnabled == true); // Overridden value
  assert(mergedCacheTtl == 3600); // Added from override

  // Example 2: Merging with arrays
  assert(featuresCount == 4); // Extended array
  assert(mergedFeatures.contains('auth'));
  assert(mergedFeatures.contains('logging'));
  assert(mergedFeatures.contains('metrics'));
  assert(mergedFeatures.contains('tracing'));

  // Example 3: Tree traversal with string processing
  assert(processedApiBaseUrl == 'https://api.example.com/api/v1');
  assert(processedHealthCheck == 'https://api.example.com/health');
  assert(processedAssets == 'https://cdn.example.com/assets');
  assert(unchangedName == 'MyApplication'); // Unchanged

  // Example 4: Path-based tree access
  assert(primaryHost == 'db1.example.com');
  assert(primaryPort == 5432);

  // Example 5: Getting objects from tree paths
  assert(redisHost == 'redis.example.com');
  assert(redisPort == 6379);
  assert(replicaConfig is Map);
  assert((replicaConfig as Map)['host'] == 'db2.example.com');

  // Example 6: JSON map sanitization
  assert(cleanMap.length == 6); // Numeric key filtered out
  assert(cleanMap.containsKey('name'));
  assert(cleanMap.containsKey('version'));
  assert(cleanMap.containsKey('active'));
  assert(cleanMap.containsKey('count'));
  assert(cleanMap.containsKey('metadata'));
  assert(cleanMap.containsKey('tags'));
  assert(!cleanMap.containsKey('123')); // Numeric key filtered (converted to string)

  // Example 7: Nested list cleaning
  assert(cleanedItems.length == 2);
  assert((cleanedItems[0] as Map)['id'] == 1);
  assert((cleanedItems[0] as Map)['name'] == 'First');
  assert(cleanedMatrix.length == 2);
  assert((cleanedMatrix[0] as List).length == 3);
  assert((cleanedMatrix[0] as List)[0] == 1);
}
