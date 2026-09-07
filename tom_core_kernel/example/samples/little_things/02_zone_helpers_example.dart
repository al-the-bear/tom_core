/// Demonstrates zone-related helper functions from the little_things module
/// including typed zone value retrieval and async checked execution.
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/little_things/02_zone_helpers_example.dart
/// ```
library;

import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

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

// =============================================================================
// EXAMPLE 1: Basic Typed Zone Value Retrieval
// =============================================================================

class BasicZoneRetrievalExample {
  static String? retrievedEnvironment;
  static int? retrievedMaxConnections;
  static bool retrievalSuccessful = false;

  static void example1BasicTypedZoneRetrieval() {
    runZoned(
      () {
        final config = getFromCurrentZone<AppConfig>();
        retrievedEnvironment = config?.environment;
        retrievedMaxConnections = config?.maxConnections;
      },
      zoneValues: {
        AppConfig: const AppConfig(
          environment: 'production',
          maxConnections: 100,
        ),
      },
    );

    retrievalSuccessful =
        retrievedEnvironment == 'production' && retrievedMaxConnections == 100;

    assert(retrievedEnvironment == 'production', 'Environment should match');
    assert(retrievedMaxConnections == 100, 'Max connections should match');
    assert(retrievalSuccessful, 'Retrieval should be successful');
  }
}

// =============================================================================
// EXAMPLE 2: Multiple Values in Same Zone
// =============================================================================

class MultipleZoneValuesExample {
  static String? configEnv;
  static String? userName;
  static List<String>? userRoles;
  static bool allValuesRetrieved = false;

  static void example2MultipleZoneValues() {
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

    allValuesRetrieved =
        configEnv == 'staging' &&
        userName == 'Alice' &&
        userRoles != null &&
        userRoles!.contains('admin');

    assert(configEnv == 'staging', 'Config environment should match');
    assert(userName == 'Alice', 'User name should match');
    assert(userRoles!.contains('admin'), 'User should have admin role');
    assert(allValuesRetrieved, 'All values should be retrieved');
  }
}

// =============================================================================
// EXAMPLE 3: Missing Zone Value Returns Null
// =============================================================================

class MissingZoneValueExample {
  static bool hasConfig = false;
  static bool hasUser = false;
  static bool missingValueIsNull = false;

  static void example3MissingZoneValue() {
    runZoned(
      () {
        // Only AppConfig is in zone, UserContext is not
        final missingConfig = getFromCurrentZone<AppConfig>();
        final missingUser = getFromCurrentZone<UserContext>();

        hasConfig = missingConfig != null;
        hasUser = missingUser != null;
      },
      zoneValues: {
        AppConfig: const AppConfig(environment: 'test', maxConnections: 10),
      },
    );

    missingValueIsNull = hasConfig && !hasUser;

    assert(hasConfig, 'Config should exist in zone');
    assert(!hasUser, 'User should not exist in zone');
    assert(missingValueIsNull, 'Missing value should be null');
  }
}

// =============================================================================
// EXAMPLE 4: Untyped Zone Value Retrieval
// =============================================================================

class UntypedZoneRetrievalExample {
  static Object? untypedConfig;
  static Type? configType;
  static bool untypedRetrievalWorks = false;

  static void example4UntypedZoneRetrieval() {
    runZoned(
      () {
        untypedConfig = getObjectFromCurrentZone(AppConfig);
        configType = untypedConfig?.runtimeType;
      },
      zoneValues: {
        AppConfig: const AppConfig(environment: 'dev', maxConnections: 25),
      },
    );

    untypedRetrievalWorks = untypedConfig != null && configType == AppConfig;

    assert(untypedConfig != null, 'Untyped config should exist');
    assert(configType == AppConfig, 'Type should be AppConfig');
    assert(untypedRetrievalWorks, 'Untyped retrieval should work');
  }
}

// =============================================================================
// EXAMPLE 5: Nested Zone Value Shadowing
// =============================================================================

class NestedZoneShadowingExample {
  static String? outerEnvironment;
  static String? innerEnvironment;
  static bool shadowingWorks = false;

  static void example5NestedZoneShadowing() {
    runZoned(
      () {
        final outerConfig = getFromCurrentZone<AppConfig>();
        outerEnvironment = outerConfig?.environment;

        runZoned(
          () {
            final innerConfig = getFromCurrentZone<AppConfig>();
            innerEnvironment = innerConfig?.environment;
          },
          zoneValues: {
            AppConfig: const AppConfig(environment: 'inner', maxConnections: 5),
          },
        );
      },
      zoneValues: {
        AppConfig: const AppConfig(environment: 'outer', maxConnections: 100),
      },
    );

    shadowingWorks = outerEnvironment == 'outer' && innerEnvironment == 'inner';

    assert(outerEnvironment == 'outer', 'Outer environment should be outer');
    assert(innerEnvironment == 'inner', 'Inner environment should be inner');
    assert(shadowingWorks, 'Shadowing should work');
  }
}

// =============================================================================
// EXAMPLE 6: Async Checked Execution
// =============================================================================

class AsyncCheckedExecutionExample {
  static int? asyncResult;
  static bool asyncExecutionSuccessful = false;

  static Future<void> example6AsyncCheckedExecution() async {
    asyncResult = await runChecked<int>(
      () async {
        await Future.delayed(Duration(milliseconds: 10));
        return 42;
      },
      (error, stacktrace) => TomException(
        'sample.async_operation.failed',
        'Async operation failed',
        rootException: error,
      ),
    );

    asyncExecutionSuccessful = asyncResult == 42;

    assert(asyncResult == 42, 'Async result should be 42');
    assert(asyncExecutionSuccessful, 'Async execution should succeed');
  }
}

// =============================================================================
// EXAMPLE 7: Async Checked Execution with Error
// =============================================================================

class AsyncCheckedErrorExample {
  static String? asyncErrorKey;
  static bool asyncErrorCaught = false;

  static Future<void> example7AsyncCheckedError() async {
    try {
      await runChecked<int>(
        () async {
          await Future.delayed(Duration(milliseconds: 10));
          throw StateError('Async state error');
        },
        (error, stacktrace) => TomException(
          'sample.async_operation.state_error',
          'State error in async operation',
          rootException: error,
        ),
      );
    } on TomException catch (e) {
      asyncErrorKey = e.key;
      asyncErrorCaught = true;
    }

    assert(
      asyncErrorKey == 'sample.async_operation.state_error',
      'Error key should match',
    );
    assert(asyncErrorCaught, 'Async error should be caught');
  }
}

// =============================================================================
// EXAMPLE 8: Zone Values Inheritance
// =============================================================================

class ZoneInheritanceExample {
  static String? parentValue;
  static String? childOnlyValue;
  static bool inheritanceWorks = false;

  static void example8ZoneInheritance() {
    runZoned(
      () {
        final parentConfig = getFromCurrentZone<AppConfig>();
        parentValue = parentConfig?.environment;

        runZoned(
          () {
            final inheritedConfig = getFromCurrentZone<AppConfig>();
            final childUser = getFromCurrentZone<UserContext>();

            // Child inherits parent's AppConfig
            childOnlyValue = childUser?.userName;

            // Verify inheritance
            inheritanceWorks =
                inheritedConfig?.environment == 'parent' &&
                childUser?.userName == 'Child User';
          },
          zoneValues: {
            UserContext: const UserContext(
              userId: 'child_001',
              userName: 'Child User',
              roles: ['viewer'],
            ),
          },
        );
      },
      zoneValues: {
        AppConfig: const AppConfig(environment: 'parent', maxConnections: 50),
      },
    );

    assert(parentValue == 'parent', 'Parent value should be parent');
    assert(childOnlyValue == 'Child User', 'Child value should be Child User');
    assert(inheritanceWorks, 'Inheritance should work');
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

Future<void> run() async {
  print('=== 02: Zone Helpers Example ===\n');

  BasicZoneRetrievalExample.example1BasicTypedZoneRetrieval();
  print('1. getFromCurrentZone reads a value back out of the zone by type:');
  print(
    '   environment      : ${BasicZoneRetrievalExample.retrievedEnvironment}',
  );
  print(
    '   max connections  : '
    '${BasicZoneRetrievalExample.retrievedMaxConnections}',
  );
  print(
    '   retrieval worked : ${BasicZoneRetrievalExample.retrievalSuccessful}',
  );
  print('');

  MultipleZoneValuesExample.example2MultipleZoneValues();
  print('2. One zone can carry several values, each keyed by its own type:');
  print('   AppConfig  env   : ${MultipleZoneValuesExample.configEnv}');
  print('   UserContext name : ${MultipleZoneValuesExample.userName}');
  print('   UserContext roles: ${MultipleZoneValuesExample.userRoles}');
  print(
    '   all retrieved    : ${MultipleZoneValuesExample.allValuesRetrieved}',
  );
  print('');

  MissingZoneValueExample.example3MissingZoneValue();
  print('3. A type the zone never got is simply null, not an error:');
  print('   AppConfig present   : ${MissingZoneValueExample.hasConfig}');
  print('   UserContext present : ${MissingZoneValueExample.hasUser}');
  print(
    '   missing one is null : ${MissingZoneValueExample.missingValueIsNull}',
  );
  print('');

  UntypedZoneRetrievalExample.example4UntypedZoneRetrieval();
  print('4. getObjectFromCurrentZone takes the Type as an argument instead:');
  print('   value            : ${UntypedZoneRetrievalExample.untypedConfig}');
  print('   runtime type     : ${UntypedZoneRetrievalExample.configType}');
  print(
    '   untyped read ok  : '
    '${UntypedZoneRetrievalExample.untypedRetrievalWorks}',
  );
  print('');

  NestedZoneShadowingExample.example5NestedZoneShadowing();
  print('5. An inner zone shadows the same type held by the outer zone:');
  print('   outer environment: ${NestedZoneShadowingExample.outerEnvironment}');
  print('   inner environment: ${NestedZoneShadowingExample.innerEnvironment}');
  print('   shadowing worked : ${NestedZoneShadowingExample.shadowingWorks}');
  print('');

  await AsyncCheckedExecutionExample.example6AsyncCheckedExecution();
  print('6. runChecked awaits the body and returns its value:');
  print('   awaited result   : ${AsyncCheckedExecutionExample.asyncResult}');
  print(
    '   execution ok     : '
    '${AsyncCheckedExecutionExample.asyncExecutionSuccessful}',
  );
  print('');

  await AsyncCheckedErrorExample.example7AsyncCheckedError();
  print('7. An error thrown inside the awaited body arrives as TomException:');
  print('   exception key    : ${AsyncCheckedErrorExample.asyncErrorKey}');
  print('   error caught     : ${AsyncCheckedErrorExample.asyncErrorCaught}');
  print('');

  ZoneInheritanceExample.example8ZoneInheritance();
  print('8. A child zone inherits what the parent zone holds:');
  print('   parent AppConfig : ${ZoneInheritanceExample.parentValue}');
  print('   child-only value : ${ZoneInheritanceExample.childOnlyValue}');
  print('   inheritance works: ${ZoneInheritanceExample.inheritanceWorks}');
  print('');
}

/// Standalone entry point.
Future<void> main() async {
  prepareSampleProcess();
  await run();
}
