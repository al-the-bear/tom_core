/// Initialization Sequence Example
///
/// This example demonstrates the complete initialization sequence for
/// dependency injection. The bean context requires the runtime system
/// to be properly configured before it can be used.
///
/// Initialization sequence:
/// 1. Set environment variables
/// 2. Set platform utilities
/// 3. Initialize reflection
/// 4. Initialize runtime
/// 5. Initialize bean context
library;

import 'package:tom_core_server/tom_core_server.dart';

// ============================================================================
// Environment Definitions
// ============================================================================

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

// ============================================================================
// Example Class
// ============================================================================

class InitializationSequenceExample {
  // Captured results
  static late String envValue;
  static late String currentEnvName;
  static late bool isDevelopment;
  static late String? platformName;
  static late List<String> registeredEnvs;

  // -------------------------------------------------------------------------
  // Example 1: Set environment variables (STEP 1)
  // -------------------------------------------------------------------------
  static void example1SetEnvironmentVariables() {
    print('1. Setting environment variables:');

    // Set environment to "dev" - determines which environment will be active
    TomPlatformUtils.envVars['env'] = 'dev';
    TomPlatformUtils.envVars['useRemoteLogging'] = 'false';
    TomPlatformUtils.envVars['apiBaseUrl'] = 'http://localhost:9080/';

    // Capture results
    envValue = TomPlatformUtils.envVars['env']!;

    print('   - env: $envValue');
    print('   - useRemoteLogging: ${TomPlatformUtils.envVars['useRemoteLogging']}');
    print('   - apiBaseUrl: ${TomPlatformUtils.envVars['apiBaseUrl']}');

    // Assertions
    assert(TomPlatformUtils.envVars['env'] == 'dev', 'Env should be dev');
    assert(TomPlatformUtils.envVars['useRemoteLogging'] == 'false', 'Remote logging should be false');
  }

  // -------------------------------------------------------------------------
  // Example 2: Set platform utilities (STEP 2)
  // -------------------------------------------------------------------------
  static void example2SetPlatformUtilities() {
    print('\n2. Setting platform utilities:');

    // Set platform utilities - must be done before initializeRuntime()
    TomPlatformUtils.setCurrentPlatform(standalonePlatformUtils);

    // Verify platform is set
    final platform = TomPlatformUtils.current;
    final envVars = platform.getTomEnvVars();

    print('   - Platform type: ${platform.runtimeType}');
    print('   - EnvVars accessible: ${envVars['env']}');

    // Assertions
    assert(platform is TomStandalonePlatformUtils, 'Should be standalone platform');
    assert(envVars['env'] == 'dev', 'EnvVars should be accessible');
  }

  // -------------------------------------------------------------------------
  // Example 3: Initialize runtime (STEP 3)
  // -------------------------------------------------------------------------
  static void example3InitializeRuntime() {
    print('\n3. Initializing runtime:');

    // Register all environments
    TomRuntime.addEnvironment(environmentProd);
    TomRuntime.addEnvironment(environmentInt);
    TomRuntime.addEnvironment(environmentDev);

    // Set root environment (base of hierarchy)
    TomRuntime.setRootEnvironment(environmentProd);

    // Set current environment from envVars (defaults to "prod" if not set)
    TomRuntime.setCurrentEnvironment(
      TomPlatformUtils.current.getTomEnvVars()['env'],
      'prod',
    );

    // Initialize platform detection
    TomRuntime.initializePlatform();

    // Capture results
    final currentEnv = TomRuntime.getCurrentEnvironment();
    currentEnvName = currentEnv.env;
    isDevelopment = currentEnv.isDevelopment;
    platformName = TomRuntime.getCurrentPlatform()?.name;
    registeredEnvs = ['prod', 'int', 'dev'];

    print('   - Registered environments: ${registeredEnvs.join(', ')}');
    print('   - Current environment: $currentEnvName');
    print('   - Is development: $isDevelopment');
    print('   - Platform: $platformName');

    // Assertions
    assert(currentEnvName == 'dev', 'Current env should be dev');
    assert(isDevelopment == true, 'Should be development mode');
    assert(platformName != null, 'Platform name should be set');
    assert(currentEnv.isTest == true, 'Should be test mode');
  }

  // -------------------------------------------------------------------------
  // Example 4: Query runtime information
  // -------------------------------------------------------------------------
  static void example4QueryRuntimeInfo() {
    print('\n4. Querying runtime information:');

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

    print('   - Parent environment: $parentName');
    print('   - Is test environment: $isTestMode');
    print('   - Is web: $isWeb');
    print('   - Is server: $isServer');

    // Assertions
    assert(hasParent == true, 'Should have parent');
    assert(parentName == 'prod', 'Parent should be prod');
    assert(isDevMode == true, 'Should be dev mode');
    assert(isTestMode == true, 'Should be test mode');
    assert(isWeb == false, 'Should not be web');
  }

  // -------------------------------------------------------------------------
  // Example 5: Print runtime report
  // -------------------------------------------------------------------------
  static void example5GetRuntimeReport() {
    print('\n5. Runtime diagnostic report:');

    final report = TomRuntime.printReport();

    // Report contains environment info
    print('   $report');

    // Assertions
    assert(report.isNotEmpty, 'Report should not be empty');
  }

  // -------------------------------------------------------------------------
  // Run all examples
  // -------------------------------------------------------------------------
  static void run() {
    print('=== 01: Initialization Sequence Example ===\n');

    example1SetEnvironmentVariables();
    example2SetPlatformUtilities();
    example3InitializeRuntime();
    example4QueryRuntimeInfo();
    example5GetRuntimeReport();

    print('\n=== Initialization Sequence Example Complete ===\n');
  }
}

void run() => InitializationSequenceExample.run();

void main() => run();
