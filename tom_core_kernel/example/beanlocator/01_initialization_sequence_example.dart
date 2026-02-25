/// Demonstrates the complete initialization sequence for dependency injection.
///
/// This example shows the correct order of initialization as used in
/// production applications. The bean context requires the runtime
/// system to be properly configured before it can be used.
///
/// Initialization sequence:
/// 1. Set environment variables
/// 2. Set platform utilities
/// 3. Initialize reflection
/// 4. Initialize runtime
/// 5. Initialize bean context
library;

import 'package:tom_core_server/tom_core_server.dart';

// =============================================================================
// Environment Definitions (as in 01_client_runtime_definition.dart)
// =============================================================================

/// Production environment - root of the hierarchy.
const environmentProd = TomEnvironment('prod');

/// Integration environment - child of prod.
const environmentInt = TomEnvironment(
  'int',
  parent: environmentProd,
  isTest: true,
);

/// Development environment - child of prod.
const environmentDev = TomEnvironment(
  'dev',
  parent: environmentProd,
  isDevelopment: true,
  isTest: true,
);

// =============================================================================
// Example Class
// =============================================================================

class InitializationSequenceExample {
  // Results captured from initialization
  static late String envValue;
  static late String currentEnvName;
  static late bool isDevelopment;
  static late String? platformName;
  static late List<String> registeredEnvs;

  // -------------------------------------------------------------------------
  // Example 1: Set environment variables (STEP 1)
  // -------------------------------------------------------------------------
  static void example1SetEnvironmentVariables() {
    // Set environment to "dev" - determines which environment will be active
    TomPlatformUtils.envVars["env"] = "dev";
    TomPlatformUtils.envVars["useRemoteLogging"] = "false";
    TomPlatformUtils.envVars["apiBaseUrl"] = "http://localhost:9080/";

    // Capture results
    envValue = TomPlatformUtils.envVars["env"]!;

    // Assertions
    assert(TomPlatformUtils.envVars["env"] == "dev");
    assert(TomPlatformUtils.envVars["useRemoteLogging"] == "false");
  }

  // -------------------------------------------------------------------------
  // Example 2: Set platform utilities (STEP 2)
  // -------------------------------------------------------------------------
  static void example2SetPlatformUtilities() {
    // Set platform utilities - must be done before initializeRuntime()
    TomPlatformUtils.setCurrentPlatform(standalonePlatformUtils);

    // Verify platform is set
    final platform = TomPlatformUtils.current;
    final envVars = platform.getTomEnvVars();

    // Assertions
    assert(platform is TomStandalonePlatformUtils);
    assert(envVars["env"] == "dev");
  }

  // -------------------------------------------------------------------------
  // Example 3: Initialize runtime (STEP 3)
  // -------------------------------------------------------------------------
  static void example3InitializeRuntime() {
    // Register all environments
    TomRuntime.addEnvironment(environmentProd);
    TomRuntime.addEnvironment(environmentInt);
    TomRuntime.addEnvironment(environmentDev);

    // Set root environment (base of hierarchy)
    TomRuntime.setRootEnvironment(environmentProd);

    // Set current environment from envVars (defaults to "prod" if not set)
    TomRuntime.setCurrentEnvironment(
      TomPlatformUtils.current.getTomEnvVars()["env"],
      "prod",
    );

    // Initialize platform detection
    TomRuntime.initializePlatform();

    // Capture results
    final currentEnv = TomRuntime.getCurrentEnvironment();
    currentEnvName = currentEnv.env;
    isDevelopment = currentEnv.isDevelopment;
    platformName = TomRuntime.getCurrentPlatform()?.name;
    registeredEnvs = ['prod', 'int', 'dev'];

    // Assertions
    assert(currentEnvName == "dev");
    assert(isDevelopment == true);
    assert(platformName != null);
    assert(currentEnv.isTest == true);
  }

  // -------------------------------------------------------------------------
  // Example 4: Query runtime information
  // -------------------------------------------------------------------------
  static void example4QueryRuntimeInfo() {
    final currentEnv = TomRuntime.getCurrentEnvironment();
    final platform = TomRuntime.getCurrentPlatform();

    // Query environment hierarchy
    final hasParent = currentEnv.parent != null;
    final parentName = currentEnv.parent?.env;

    // Query environment flags
    final isDevMode = currentEnv.isDevelopment;
    final isTestMode = currentEnv.isTest;

    // Query platform capabilities
    final isWeb = platform?.name.contains('web') ?? false;
    final isServer = platform?.name.contains('standalone') ?? true;

    // Assertions
    assert(hasParent == true);
    assert(parentName == "prod");
    assert(isDevMode == true);
    assert(isTestMode == true);
    assert(isWeb == false);
    assert(isServer == true);
  }

  // -------------------------------------------------------------------------
  // Example 5: Print runtime report
  // -------------------------------------------------------------------------
  static String example5GetRuntimeReport() {
    final report = TomRuntime.printReport();

    // Report contains environment info
    assert(report.contains("dev") || report.isNotEmpty);

    return report;
  }

  // -------------------------------------------------------------------------
  // Run all examples
  // -------------------------------------------------------------------------
  static void run() {
    print('=== 01: Initialization Sequence Example ===\n');

    print('1. Setting environment variables:');
    example1SetEnvironmentVariables();
    print('   - env: $envValue');
    print('   - useRemoteLogging: ${TomPlatformUtils.envVars["useRemoteLogging"]}');
    print('   - apiBaseUrl: ${TomPlatformUtils.envVars["apiBaseUrl"]}');

    print('\n2. Setting platform utilities:');
    example2SetPlatformUtilities();
    print('   - Platform type: ${TomPlatformUtils.current.runtimeType}');
    print('   - EnvVars accessible: ${TomPlatformUtils.current.getTomEnvVars()["env"]}');

    print('\n3. Initializing runtime:');
    example3InitializeRuntime();
    print('   - Registered environments: ${registeredEnvs.join(", ")}');
    print('   - Current environment: $currentEnvName');
    print('   - Is development: $isDevelopment');
    print('   - Platform: $platformName');

    print('\n4. Querying runtime information:');
    example4QueryRuntimeInfo();
    final env = TomRuntime.getCurrentEnvironment();
    print('   - Parent environment: ${env.parent?.env}');
    print('   - Is test environment: ${env.isTest}');

    print('\n5. Runtime diagnostic report:');
    final report = example5GetRuntimeReport();
    print('   $report');

    print('\n=== All assertions passed! ===\n');
  }
}

void run() {
  InitializationSequenceExample.run();
}
