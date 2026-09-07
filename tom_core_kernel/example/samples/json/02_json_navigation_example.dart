/// Demonstrates JSON navigation and manipulation utilities including
/// deep merging, tree traversal, path-based access, and JSON sanitization.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

// =============================================================================
// EXAMPLE 1: Basic Map Merging
// =============================================================================

class BasicMergingExample {
  static String? mergedHost;
  static int? mergedPort;
  static bool? mergedCacheEnabled;
  static int? mergedCacheTtl;
  static bool mergeSuccessful = false;

  static void example1BasicMapMerging() {
    final baseConfig = <String, dynamic>{
      'database': <String, Object>{'host': 'localhost', 'port': 5432},
      'cache': <String, Object>{'enabled': false},
    };
    final overrideConfig = <String, dynamic>{
      'database': <String, Object>{'host': 'production.db.com'},
      'cache': <String, Object>{'enabled': true, 'ttl': 3600},
    };

    mergeMapsOneSided(baseConfig, overrideConfig);

    mergedHost = baseConfig['database']['host'] as String?;
    mergedPort = baseConfig['database']['port'] as int?;
    mergedCacheEnabled = baseConfig['cache']['enabled'] as bool?;
    mergedCacheTtl = baseConfig['cache']['ttl'] as int?;

    mergeSuccessful =
        mergedHost == 'production.db.com' &&
        mergedPort == 5432 &&
        mergedCacheEnabled == true &&
        mergedCacheTtl == 3600;

    assert(mergedHost == 'production.db.com', 'Host should be overridden');
    assert(mergedPort == 5432, 'Port should be preserved');
    assert(mergedCacheEnabled == true, 'Cache enabled should be overridden');
    assert(mergedCacheTtl == 3600, 'TTL should be added');
    assert(mergeSuccessful, 'Merge should be successful');
  }
}

// =============================================================================
// EXAMPLE 2: Merging with Arrays
// =============================================================================

class ArrayMergingExample {
  static List<dynamic>? mergedFeatures;
  static int featuresCount = 0;
  static bool hasMetrics = false;

  static void example2MergingWithArrays() {
    final baseWithArray = <String, dynamic>{
      'features': ['auth', 'logging'],
      'servers': [
        <String, Object>{'name': 'primary', 'port': 8080},
      ],
    };
    final overrideWithArray = <String, dynamic>{
      'features': ['auth', 'logging', 'metrics', 'tracing'],
    };

    mergeMapsOneSided(baseWithArray, overrideWithArray);

    mergedFeatures = baseWithArray['features'] as List<dynamic>?;
    featuresCount = mergedFeatures?.length ?? 0;
    hasMetrics = mergedFeatures?.contains('metrics') ?? false;

    assert(featuresCount == 4, 'Should have 4 features after merge');
    assert(hasMetrics, 'Should contain metrics feature');
  }
}

// =============================================================================
// EXAMPLE 3: Tree Traversal with String Processing
// =============================================================================

class TreeTraversalExample {
  static String? processedBaseUrl;
  static String? processedAssets;
  static String? unchangedName;
  static bool processingComplete = false;

  static void example3TreeTraversal() {
    final templateConfig = <String, Object>{
      'api': <String, Object>{
        'baseUrl': r'${BASE_URL}/api/v1',
        'healthCheck': r'${BASE_URL}/health',
      },
      'static': <String, Object>{'assets': r'${CDN_URL}/assets'},
      'name': 'MyApplication',
    };

    traverseAndProcess(
      templateConfig,
      (s) => s.contains(r'${'),
      (s) => s
          .replaceAll(r'${BASE_URL}', 'https://api.example.com')
          .replaceAll(r'${CDN_URL}', 'https://cdn.example.com'),
    );

    processedBaseUrl =
        (templateConfig['api'] as Map<String, Object>)['baseUrl'] as String?;
    processedAssets =
        (templateConfig['static'] as Map<String, Object>)['assets'] as String?;
    unchangedName = templateConfig['name'] as String?;

    processingComplete =
        processedBaseUrl == 'https://api.example.com/api/v1' &&
        processedAssets == 'https://cdn.example.com/assets' &&
        unchangedName == 'MyApplication';

    assert(
      processedBaseUrl == 'https://api.example.com/api/v1',
      'Base URL should be processed',
    );
    assert(
      processedAssets == 'https://cdn.example.com/assets',
      'Assets should be processed',
    );
    assert(unchangedName == 'MyApplication', 'Name should be unchanged');
    assert(processingComplete, 'Processing should complete');
  }
}

// =============================================================================
// EXAMPLE 4: Path-Based Tree Access
// =============================================================================

class PathAccessExample {
  static String? primaryHost;
  static int? primaryPort;
  static bool pathAccessWorks = false;

  static void example4PathBasedAccess() {
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
    primaryHost = primaryDb['host'] as String?;
    primaryPort = primaryDb['port'] as int?;

    pathAccessWorks = primaryHost == 'db1.example.com' && primaryPort == 5432;

    assert(primaryHost == 'db1.example.com', 'Host should match');
    assert(primaryPort == 5432, 'Port should match');
    assert(pathAccessWorks, 'Path access should work');
  }
}

// =============================================================================
// EXAMPLE 5: Getting Objects from Tree Paths
// =============================================================================

class ObjectFromTreeExample {
  static String? redisHost;
  static int? redisPort;
  static Map<String, dynamic>? replicaConfig;
  static bool objectAccessWorks = false;

  static void example5GetObjectFromTree() {
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

    redisHost =
        getObjectFromTree(deepConfig, 'services.cache.redis.host') as String?;
    redisPort =
        getObjectFromTree(deepConfig, 'services.cache.redis.port') as int?;
    replicaConfig =
        getObjectFromTree(deepConfig, 'services.database.replica')
            as Map<String, dynamic>?;

    objectAccessWorks =
        redisHost == 'redis.example.com' &&
        redisPort == 6379 &&
        replicaConfig != null;

    assert(redisHost == 'redis.example.com', 'Redis host should match');
    assert(redisPort == 6379, 'Redis port should match');
    assert(replicaConfig != null, 'Replica config should exist');
    assert(objectAccessWorks, 'Object access should work');
  }
}

// =============================================================================
// EXAMPLE 6: JSON Map Sanitization
// =============================================================================

class MapSanitizationExample {
  static int originalEntryCount = 0;
  static int cleanedEntryCount = 0;
  static bool everyStringKeySurvived = false;
  static bool cleaningWorks = false;

  static void example6MapSanitization() {
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

    originalEntryCount = dirtyMap.length;
    final cleanMap = makeCleanJsonMap(dirtyMap);
    cleanedEntryCount = cleanMap.length;

    // `makeCleanJsonMap` returns `Map<String, Object?>`, so asking whether its
    // keys are Strings is a question the return type has already answered —
    // and so is asking whether the numeric key survived, since it could not
    // have been stored. What is worth checking is the other half of the
    // filter: that dropping the numeric key cost nothing else. With the entry
    // counts asserted below, "every string key survived" pins the outcome
    // exactly.
    everyStringKeySurvived = dirtyMap.keys.whereType<String>().every(
      (key) => cleanMap.containsKey(key),
    );
    cleaningWorks =
        cleanedEntryCount < originalEntryCount && everyStringKeySurvived;

    assert(originalEntryCount == 7, 'Original should have 7 entries');
    assert(
      cleanedEntryCount == 6,
      'Cleaned should have 6 entries (no numeric key)',
    );
    assert(
      everyStringKeySurvived,
      'Dropping the non-string key should cost no string key',
    );
    assert(cleaningWorks, 'Cleaning should work');
  }
}

// =============================================================================
// EXAMPLE 7: Missing path handling
// =============================================================================

class MissingPathExample {
  static Object? foundValue;
  static dynamic missingValue;
  static bool throwsForMissing = false;
  static bool clearedIsNull = false;

  static void example7MissingPathHandling() {
    final config = <String, dynamic>{
      'level1': {
        'level2': {'value': 'found', 'cleared': null},
      },
    };

    foundValue = getObjectFromTree(config, 'level1.level2.value');

    // getObjectFromTree throws an exception for missing paths.
    try {
      missingValue = getObjectFromTree(config, 'level1.level2.notHere');
    } on Exception catch (e) {
      throwsForMissing = true;
      missingValue = e.toString();
    }

    // A key that is present and holds null is a *value*, not an absence, so it
    // is returned rather than thrown for. That is what separates "the operator
    // deliberately cleared this" from "nobody ever set it" — the two cases
    // need different handling, and only one of them may fall back to a default.
    final cleared = getObjectFromTree(config, 'level1.level2.cleared');
    clearedIsNull = cleared == null;

    assert(foundValue == 'found', 'Existing value should be found');
    assert(throwsForMissing, 'Missing path should throw Exception');
    assert(clearedIsNull, 'A present-but-null path should resolve to null');
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

void run() {
  print('=== 02: JSON Navigation Example ===\n');

  BasicMergingExample.example1BasicMapMerging();
  print('1. mergeMapsOneSided overlays an override onto a base config:');
  print('   database.host  : ${BasicMergingExample.mergedHost} (overridden)');
  print('   database.port  : ${BasicMergingExample.mergedPort} (kept)');
  print('   cache.enabled  : ${BasicMergingExample.mergedCacheEnabled}');
  print('   cache.ttl      : ${BasicMergingExample.mergedCacheTtl} (added)');
  print('   as expected    : ${BasicMergingExample.mergeSuccessful}');
  print('');

  ArrayMergingExample.example2MergingWithArrays();
  print('2. A list in the override replaces the list in the base:');
  print('   features       : ${ArrayMergingExample.mergedFeatures}');
  print('   feature count  : ${ArrayMergingExample.featuresCount}');
  print('   has "metrics"  : ${ArrayMergingExample.hasMetrics}');
  print('');

  TreeTraversalExample.example3TreeTraversal();
  print('3. traverseAndProcess rewrites only the strings that match:');
  print('   api.baseUrl    : ${TreeTraversalExample.processedBaseUrl}');
  print('   static.assets  : ${TreeTraversalExample.processedAssets}');
  print(
    '   name           : ${TreeTraversalExample.unchangedName} (untouched)',
  );
  print('   as expected    : ${TreeTraversalExample.processingComplete}');
  print('');

  PathAccessExample.example4PathBasedAccess();
  print('4. getPathFromTree reaches a nested map by dotted path:');
  print('   services.database.primary.host : ${PathAccessExample.primaryHost}');
  print('   services.database.primary.port : ${PathAccessExample.primaryPort}');
  print(
    '   path access works              : '
    '${PathAccessExample.pathAccessWorks}',
  );
  print('');

  ObjectFromTreeExample.example5GetObjectFromTree();
  print('5. getObjectFromTree returns leaves or whole subtrees:');
  print('   ...cache.redis.host      : ${ObjectFromTreeExample.redisHost}');
  print('   ...cache.redis.port      : ${ObjectFromTreeExample.redisPort}');
  print('   ...database.replica      : ${ObjectFromTreeExample.replicaConfig}');
  print(
    '   object access works      : '
    '${ObjectFromTreeExample.objectAccessWorks}',
  );
  print('');

  MapSanitizationExample.example6MapSanitization();
  print('6. makeCleanJsonMap drops entries JSON cannot represent:');
  print('   entries before  : ${MapSanitizationExample.originalEntryCount}');
  print('   entries after   : ${MapSanitizationExample.cleanedEntryCount}');
  print(
    '   every string key survived : '
    '${MapSanitizationExample.everyStringKeySurvived}',
  );
  print('   cleaning works  : ${MapSanitizationExample.cleaningWorks}');
  print('');

  MissingPathExample.example7MissingPathHandling();
  print('7. Missing, present-but-null, and present paths differ:');
  print('   level1.level2.value    : ${MissingPathExample.foundValue}');
  print(
    '   level1.level2.notHere  : threw an Exception '
    '(${MissingPathExample.throwsForMissing})',
  );
  print(
    '   level1.level2.cleared  : null, returned not thrown '
    '(${MissingPathExample.clearedIsNull})',
  );
  print('');
}

void main() {
  prepareSampleProcess();
  run();
}
