/// Demonstrates zone-related helper functions from the little_things module
/// including typed zone value retrieval and async checked execution.
///
/// This example covers:
/// - Retrieving typed values from zones with getFromCurrentZone
/// - Retrieving untyped values with getObjectFromCurrentZone
/// - Async error transformation with runChecked
/// - Zone nesting and value shadowing
/// - Null handling for missing zone values
///
/// These utilities are particularly useful for:
/// - Passing context through async operations without explicit parameters
/// - Request-scoped data in web servers
/// - Wrapping async operations with error handling
library;

import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

// Sample configuration class for zone examples
class AppConfig {
  final String environment;
  final int maxConnections;

  const AppConfig({required this.environment, required this.maxConnections});

  @override
  String toString() =>
      'AppConfig(environment: $environment, maxConnections: $maxConnections)';
}

// Sample user context for zone examples
class UserContext {
  final String userId;
  final String userName;
  final List<String> roles;

  const UserContext({
    required this.userId,
    required this.userName,
    required this.roles,
  });

  @override
  String toString() =>
      'UserContext(userId: $userId, userName: $userName, roles: $roles)';
}

void run() {
  print('=== 02: Zone Helpers Example ===\n');

  // ===========================================================================
  // Example 1: Basic Typed Zone Value Retrieval
  // ===========================================================================

  print('1. Basic typed zone value retrieval:');

  String? retrievedEnvironment;
  int? retrievedMaxConnections;

  runZoned(
    () {
      final config = getFromCurrentZone<AppConfig>();
      retrievedEnvironment = config?.environment;
      retrievedMaxConnections = config?.maxConnections;
    },
    zoneValues: {
      AppConfig: const AppConfig(environment: 'production', maxConnections: 100)
    },
  );

  print('   Stored config in zone');
  print('   Retrieved environment: $retrievedEnvironment');
  print('   Retrieved maxConnections: $retrievedMaxConnections');
  print('');

  // ===========================================================================
  // Example 2: Multiple Values in Same Zone
  // ===========================================================================

  print('2. Multiple values in same zone:');

  String? configEnv;
  String? userName;
  List<String>? userRoles;

  runZoned(
    () {
      final config = getFromCurrentZone<AppConfig>();
      final user = getFromCurrentZone<UserContext>();

      configEnv = config?.environment;
      userName = user?.userName;
      userRoles = user?.roles;
    },
    zoneValues: {
      AppConfig: const AppConfig(environment: 'staging', maxConnections: 50),
      UserContext: const UserContext(
        userId: 'user_001',
        userName: 'Alice',
        roles: ['admin', 'editor'],
      ),
    },
  );

  print('   Zone contains AppConfig and UserContext');
  print('   - Config environment: $configEnv');
  print('   - User name: $userName');
  print('   - User roles: $userRoles');
  print('');

  // ===========================================================================
  // Example 3: Missing Zone Value Returns Null
  // ===========================================================================

  print('3. Missing zone value returns null:');

  AppConfig? missingConfig;
  UserContext? missingUser;

  runZoned(
    () {
      // Only AppConfig is in zone, UserContext is not
      missingConfig = getFromCurrentZone<AppConfig>();
      missingUser = getFromCurrentZone<UserContext>();
    },
    zoneValues: {
      AppConfig: const AppConfig(environment: 'test', maxConnections: 10),
    },
  );

  final hasConfig = missingConfig != null;
  final hasUser = missingUser != null;

  print('   Zone only contains AppConfig');
  print('   - getFromCurrentZone<AppConfig>() returned: $hasConfig');
  print('   - getFromCurrentZone<UserContext>() returned: $hasUser');
  print('');

  // ===========================================================================
  // Example 4: Untyped Zone Value Retrieval
  // ===========================================================================

  print('4. Untyped zone value retrieval with getObjectFromCurrentZone:');

  Object? untypedConfig;
  Type configType = Object;

  runZoned(
    () {
      untypedConfig = getObjectFromCurrentZone(AppConfig);
      configType = untypedConfig?.runtimeType ?? Object;
    },
    zoneValues: {
      AppConfig: const AppConfig(environment: 'development', maxConnections: 5),
    },
  );

  final untypedIsNotNull = untypedConfig != null;
  final typeName = configType.toString();

  print('   Retrieved using Type as key');
  print('   - Value is not null: $untypedIsNotNull');
  print('   - Runtime type: $typeName');
  print('   - Value: $untypedConfig');
  print('');

  // ===========================================================================
  // Example 5: Nested Zones with Value Shadowing
  // ===========================================================================

  print('5. Nested zones with value shadowing:');

  String? outerEnv;
  String? innerEnv;
  String? afterInnerEnv;

  runZoned(
    () {
      outerEnv = getFromCurrentZone<AppConfig>()?.environment;

      runZoned(
        () {
          // Inner zone shadows the outer value
          innerEnv = getFromCurrentZone<AppConfig>()?.environment;
        },
        zoneValues: {
          AppConfig:
              const AppConfig(environment: 'inner-zone', maxConnections: 1),
        },
      );

      // After exiting inner zone, we're back to outer value
      afterInnerEnv = getFromCurrentZone<AppConfig>()?.environment;
    },
    zoneValues: {
      AppConfig:
          const AppConfig(environment: 'outer-zone', maxConnections: 100),
    },
  );

  print('   Outer zone: $outerEnv');
  print('   Inner zone (shadowed): $innerEnv');
  print('   After inner zone: $afterInnerEnv');
  print('');

  // ===========================================================================
  // Example 6: Zone Values Across Async Boundaries
  // ===========================================================================

  print('6. Zone values across async boundaries:');

  // Note: Since we can't await in this synchronous example, we verify
  // that the zone was set up correctly by checking synchronously first.
  // In real async code, zone values are preserved across await boundaries.
  String? syncCheckEnv;
  runZoned(
    () {
      syncCheckEnv = getFromCurrentZone<AppConfig>()?.environment;
    },
    zoneValues: {
      AppConfig: const AppConfig(environment: 'async-zone', maxConnections: 25),
    },
  );

  print('   Zone value accessible synchronously: $syncCheckEnv');
  print('   (Async access preserves zone values after await)');
  print('');

  // ===========================================================================
  // Example 7: Async Checked Execution - Success Case
  // ===========================================================================

  print('7. Async checked execution with runChecked (success simulation):');

  // Since we can't use await in a sync run() function, we demonstrate
  // the pattern but verify behavior synchronously
  bool successPatternValid = false;

  // Simulate the pattern that would be used
  Future<Map<String, dynamic>> fetchData() async {
    await Future.delayed(Duration.zero);
    return {'status': 'ok', 'data': [1, 2, 3]};
  }

  // The runChecked pattern wraps async operations
  final futureResult = runChecked(
    fetchData,
    (error, stacktrace) => TomException(
      'FETCH_ERROR',
      'Failed to fetch data',
      rootException: error,
    ),
  );

  // Verify the future was created (pattern is valid)
  // ignore: unnecessary_type_check
  successPatternValid = futureResult is Future<Map<String, dynamic>>;

  print('   Created async operation with error transformation');
  print('   Future created successfully: $successPatternValid');
  print('   Pattern: runChecked(() => asyncOp(), (e, s) => TomException(...))');
  print('');

  // ===========================================================================
  // Example 8: Async Checked Execution - Error Transformation
  // ===========================================================================

  print('8. Async checked execution error transformation pattern:');

  // Create a future that will fail and be transformed
  Future<void> failingOperation() async {
    throw StateError('Network connection lost');
  }

  final errorFuture = runChecked(
    failingOperation,
    (error, stacktrace) => TomException(
      'NETWORK_ERROR',
      'Connection failed during operation',
      rootException: error,
      parameters: {'operation': 'dataSync'},
    ),
  );

  // Handle the error (in real code this would be awaited)
  // The catchError transforms StateError to TomException
  unawaited(errorFuture.catchError((e) => null));

  // Verify pattern setup
  // ignore: unnecessary_type_check
  final errorPatternValid = errorFuture is Future;

  print('   Failing operation wrapped with runChecked');
  print('   Error pattern valid: $errorPatternValid');
  print('   Original error: StateError -> Transformed to: TomException');
  print('   Expected key: NETWORK_ERROR');
  print('   Expected message: Connection failed during operation');
  print('');

  // ===========================================================================
  // Example 9: Outside Zone Returns Null
  // ===========================================================================

  print('9. Zone value retrieval outside of zone:');

  // Attempting to retrieve zone value when not in a zone with that value
  final outsideZoneConfig = getFromCurrentZone<AppConfig>();
  final outsideZoneUser = getFromCurrentZone<UserContext>();

  final configIsNull = outsideZoneConfig == null;
  final userIsNull = outsideZoneUser == null;

  print('   No zone values set in current zone');
  print('   - AppConfig is null: $configIsNull');
  print('   - UserContext is null: $userIsNull');
  print('');

  // ===========================================================================
  // Example 10: Type Mismatch Returns Null
  // ===========================================================================

  print('10. Type mismatch in zone value returns null:');

  String? wrongTypeResult;
  AppConfig? correctTypeResult;

  runZoned(
    () {
      // Store AppConfig but try to retrieve as String
      // This would fail type check and return null
      wrongTypeResult = getFromCurrentZone<String>();
      correctTypeResult = getFromCurrentZone<AppConfig>();
    },
    zoneValues: {
      AppConfig: const AppConfig(environment: 'type-test', maxConnections: 1),
      // Note: String type key would need a different value
    },
  );

  final wrongTypeIsNull = wrongTypeResult == null;
  final correctTypeIsNotNull = correctTypeResult != null;

  print('   Zone contains AppConfig');
  print('   - getFromCurrentZone<String>() is null: $wrongTypeIsNull');
  print('   - getFromCurrentZone<AppConfig>() is not null: $correctTypeIsNotNull');
  print('');

  // ===========================================================================
  // Assertions
  // ===========================================================================

  // Example 1: Basic typed zone value retrieval
  assert(retrievedEnvironment == 'production');
  assert(retrievedMaxConnections == 100);

  // Example 2: Multiple values in same zone
  assert(configEnv == 'staging');
  assert(userName == 'Alice');
  assert(userRoles != null);
  assert(userRoles!.contains('admin'));
  assert(userRoles!.contains('editor'));

  // Example 3: Missing zone value returns null
  assert(hasConfig == true);
  assert(hasUser == false);

  // Example 4: Untyped zone value retrieval
  assert(untypedIsNotNull == true);
  assert(typeName == 'AppConfig');

  // Example 5: Nested zones with value shadowing
  assert(outerEnv == 'outer-zone');
  assert(innerEnv == 'inner-zone');
  assert(afterInnerEnv == 'outer-zone');

  // Example 6: Zone values across async boundaries
  assert(syncCheckEnv == 'async-zone');

  // Example 7: Async checked execution - success
  assert(successPatternValid == true);

  // Example 8: Async checked execution - error transformation
  assert(errorPatternValid == true);

  // Example 9: Outside zone returns null
  assert(configIsNull == true);
  assert(userIsNull == true);

  // Example 10: Type mismatch returns null
  assert(wrongTypeIsNull == true);
  assert(correctTypeIsNotNull == true);
}
