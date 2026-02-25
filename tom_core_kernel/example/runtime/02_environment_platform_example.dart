/// Demonstrates environment and platform configuration using TomRuntime.
///
/// This example shows how to use TomEnvironment and TomPlatform to configure
/// different runtime contexts (development, test, production) and target
/// platforms (iOS, Android, Web, etc.).
library;

import 'package:tom_core_server/tom_core_server.dart';

void run() {
  print('=== 02: Environment and Platform Configuration Example ===\n');

  // -------------------------------------------------------------------------
  // Example 1: Defining custom environments
  // -------------------------------------------------------------------------
  print('1. Defining custom environments:');

  // Create a hierarchy of environments
  const baseEnv = TomEnvironment('base');
  const devEnv = TomEnvironment(
    'development',
    parent: baseEnv,
    isDevelopment: true,
  );
  const testEnv = TomEnvironment(
    'test',
    parent: devEnv,
    isTest: true,
  );
  const prodEnv = TomEnvironment(
    'production',
    parent: baseEnv,
  );

  print('   - Base environment: ${baseEnv.env}');
  print('   - Dev environment: ${devEnv.env} (parent: ${devEnv.parent?.env})');
  print('   - Test environment: ${testEnv.env} (parent: ${testEnv.parent?.env})');
  print('   - Prod environment: ${prodEnv.env} (parent: ${prodEnv.parent?.env})');

  // -------------------------------------------------------------------------
  // Example 2: Environment initializers
  // -------------------------------------------------------------------------
  print('\n2. Environment with initializer:');

  var initCount = 0;
  final envWithInit = TomEnvironment(
    'custom',
    initializer: (env) {
      initCount++;
      print('   [Initializer] Environment ${env.env} initialized!');
    },
  );

  print('   - Before initialize: initCount = $initCount');
  envWithInit.initialize();
  print('   - After initialize: initCount = $initCount');

  // -------------------------------------------------------------------------
  // Example 3: Built-in platform constants
  // -------------------------------------------------------------------------
  print('\n3. Built-in platform constants:');
  print('   - platformWeb: ${platformWeb.name}');
  print('   - platformMacos: ${platformMacos.name}');
  print('   - platformWindows: ${platformWindows.name}');
  print('   - platformLinux: ${platformLinux.name}');
  print('   - platformAndroid: ${platformAndroid.name}');
  print('   - platformIos: ${platformIos.name}');
  print('   - platformFuchsia: ${platformFuchsia.name}');

  // -------------------------------------------------------------------------
  // Example 4: Setting up runtime
  // -------------------------------------------------------------------------
  print('\n4. Setting up runtime:');

  // Register environments
  TomRuntime.addEnvironment(devEnv);
  TomRuntime.addEnvironment(prodEnv);
  TomRuntime.addEnvironment(testEnv);

  // Set current environment (typically from config)
  TomRuntime.setCurrentEnvironment('development');

  // Set platform utils for standalone/server context before initializing
  TomPlatformUtils.setCurrentPlatform(TomStandalonePlatformUtils());

  // Initialize platform (auto-detects)
  TomRuntime.initializePlatform();

  print('   - Current environment: ${TomRuntime.getCurrentEnvironment().env}');
  print('   - Current platform: ${TomRuntime.getCurrentPlatform()?.name}');
  print('   - Environment is dev: ${TomRuntime.getCurrentEnvironment().isDevelopment}');

  // -------------------------------------------------------------------------
  // Example 5: Environment hierarchy
  // -------------------------------------------------------------------------
  print('\n5. Environment hierarchy:');

  final hierarchy = TomRuntime.getEnvironmentHierarchy();
  print('   Hierarchy (root to current):');
  for (var env in hierarchy) {
    print('   - ${env.env}');
  }

  // -------------------------------------------------------------------------
  // Example 6: Runtime report
  // -------------------------------------------------------------------------
  print('\n6. Runtime diagnostic report:');
  print('   ${TomRuntime.printReport()}');

  print('\n');

  // =========================================================================
  // Assertions
  // =========================================================================

  // Example 1: Environment hierarchy assertions
  assert(devEnv.parent == baseEnv);
  assert(testEnv.parent == devEnv);
  assert(testEnv.isTest == true);
  assert(devEnv.isDevelopment == true);

  // Example 2: Initializer assertions
  assert(initCount == 1);

  // Example 4: Runtime assertions
  assert(TomRuntime.getCurrentEnvironment().isDevelopment == true);
  assert(TomRuntime.getCurrentPlatform() != null);

  // Example 5: Hierarchy assertions
  assert(hierarchy.isNotEmpty);
}
