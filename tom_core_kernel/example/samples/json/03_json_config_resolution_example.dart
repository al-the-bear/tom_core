/// Demonstrates the configuration-resolution side of the JSON module:
/// environment-variable substitution, key-name-driven node creation, and
/// profile-based reference injection — plus the [TomJsonSerializable] contract.
///
/// This example covers:
/// - Environment variable expansion with defaults (substituteEnvVars)
/// - Key-name-driven traversal that discovers directive keys (traverseAndCreate)
/// - Profile-based reference resolution and spreading (processTree)
/// - Implementing the JSON serialization contract (TomJsonSerializable)
///
/// These are the building blocks a layered configuration loader uses to turn a
/// raw config tree (with `${VAR}` placeholders and `key@path@profile` directives)
/// into a fully resolved structure ready for serialization.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A small domain object that opts into JSON serialization via the framework
/// contract [TomJsonSerializable].
class ServiceEndpoint implements TomJsonSerializable {
  ServiceEndpoint(this.name, this.url, this.enabled, {this.region});

  final String name;
  final String url;
  final bool enabled;

  /// Absent for a globally routed endpoint. Reported as an explicit `null`
  /// rather than omitted, so a consumer can tell "no region" from "the sender
  /// did not say".
  final String? region;

  @override
  Map<String, Object?> toJson() => {
    'name': name,
    'url': url,
    'enabled': enabled,
    'region': region,
  };
}

void run() {
  print('=== 03: JSON Config Resolution Example ===\n');

  // ===========================================================================
  // Example 1: Environment variable substitution (with defaults)
  // ===========================================================================

  print('1. Environment variable substitution:');

  final envConfig = <String, dynamic>{
    'database': <String, dynamic>{
      'host': r'${DB_HOST:localhost}',
      'port': r'${DB_PORT:5432}',
    },
    'endpoints': <String>[r'${BASE_URL}/api', r'${BASE_URL}/health'],
    'missing': r'${NOT_SET}',
  };

  final environment = <String, String>{
    'DB_HOST': 'production.db.com',
    // DB_PORT deliberately absent -> default (5432) is used.
    'BASE_URL': 'https://api.example.com',
    // NOT_SET absent and no default -> placeholder left unchanged.
  };

  substituteEnvVars(envConfig, environment);

  final resolvedHost =
      (envConfig['database'] as Map<String, dynamic>)['host'] as String;
  final resolvedPort =
      (envConfig['database'] as Map<String, dynamic>)['port'] as String;
  final resolvedEndpoints = envConfig['endpoints'] as List;
  final unresolved = envConfig['missing'] as String;

  print('   - database.host: $resolvedHost (from environment)');
  print('   - database.port: $resolvedPort (from default)');
  print('   - endpoints:     $resolvedEndpoints');
  print('   - missing:       $unresolved (left unchanged)');
  print('');

  // ===========================================================================
  // Example 2: Key-name-driven node discovery (traverseAndCreate)
  // ===========================================================================

  print('2. Discovering directive keys with traverseAndCreate:');

  final directiveTree = <String, dynamic>{
    'plain': 'value',
    'link@shared@dev': '@',
    'nested': <String, dynamic>{
      'ref@profiles@prod': '...',
    },
  };

  final discovered = <String>[];
  traverseAndCreate(
    directiveTree,
    (name) => name.contains('@'),
    (key, value, location) => discovered.add('$key=$value'),
  );

  print('   Discovered directive keys: $discovered');
  print('');

  // ===========================================================================
  // Example 3: Profile-based reference injection (processTree)
  // ===========================================================================

  print('3. Resolving profile references with processTree:');

  // A profile store the provider resolves references against.
  final profiles = <String, Map<String, dynamic>>{
    'production': <String, dynamic>{
      'database': <String, dynamic>{'host': 'prod.db', 'port': 5432},
      'featureFlags': <String, dynamic>{'beta': false, 'audit': true},
    },
  };

  final tree = <String, dynamic>{
    // "@" directive: replace with the resolved value at [keyName].
    'database@services.database@production': '@',
    // "..." directive: spread the resolved map into this map (non-overwriting).
    'flags@services.featureFlags@production': '...',
    'audit': 'preset', // pre-existing key must survive the spread
  };

  processTree(tree, (keyName, path, profileName) {
    final profile = profiles[profileName]!;
    // Return a map keyed by [keyName] so the "@" directive can pick it out,
    // while its entries are also available for the "..." spread.
    final resolved = keyName == 'database'
        ? profile['database'] as Map<String, dynamic>
        : profile['featureFlags'] as Map<String, dynamic>;
    return <String, dynamic>{keyName: resolved, ...resolved};
  });

  final resolvedDb = tree['database'] as Map<String, dynamic>;
  print('   - database (via @):  $resolvedDb');
  print('   - beta (via ...):    ${tree['beta']}');
  print('   - audit (preserved): ${tree['audit']}');
  print('');

  // ===========================================================================
  // Example 4: TomJsonSerializable contract + JSON sanitization
  // ===========================================================================

  print('4. TomJsonSerializable + makeCleanJsonMap:');

  final endpoint = ServiceEndpoint(
    'auth',
    'https://api.example.com/auth',
    true,
  );
  final endpointJson = endpoint.toJson();

  // toJson output can be fed straight into makeCleanJsonMap for serialization.
  // The deliberate null the endpoint reports for `region` survives: null is a
  // JSON value, and only what has no JSON form at all is filtered out.
  final cleanEndpoint = makeCleanJsonMap(endpointJson);

  print('   - endpoint.toJson(): $endpointJson');
  print('   - cleaned:           $cleanEndpoint');
  print('   - region present:    ${cleanEndpoint.containsKey('region')}');
  print('');

  // ===========================================================================
  // Assertions
  // ===========================================================================

  // Example 1: environment substitution
  assert(resolvedHost == 'production.db.com');
  assert(resolvedPort == '5432'); // default applied
  assert(resolvedEndpoints[0] == 'https://api.example.com/api');
  assert(resolvedEndpoints[1] == 'https://api.example.com/health');
  assert(unresolved == r'${NOT_SET}'); // no value, no default

  // Example 2: directive-key discovery
  assert(discovered.contains('link@shared@dev=@'));
  assert(discovered.contains('ref@profiles@prod=...'));
  assert(discovered.length == 2);

  // Example 3: profile-based injection
  assert(resolvedDb['host'] == 'prod.db');
  assert(resolvedDb['port'] == 5432);
  assert(tree['beta'] == false); // spread from "..."
  assert(tree['audit'] == 'preset'); // pre-existing key not overwritten
  assert(tree['flags'] is Map); // spread also injected the keyName map

  // Example 4: TomJsonSerializable
  assert(endpointJson['name'] == 'auth');
  assert(endpointJson['enabled'] == true);
  assert(cleanEndpoint.length == 4);
  assert(cleanEndpoint['url'] == 'https://api.example.com/auth');
  // The null is kept, so "no region" stays distinguishable from "not stated".
  assert(cleanEndpoint.containsKey('region'));
  assert(cleanEndpoint['region'] == null);
}
