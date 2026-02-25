/// Demonstrates the complete runtime initialization sequence.
///
/// This example shows the proper order of initialization as used in
/// production applications like tom_uam_client and tom_uam_server.
/// The sequence is:
/// 1. Set environment variables
/// 2. Set platform utilities
/// 3. Initialize reflection
/// 4. Initialize runtime (environments + platform)
/// 5. Initialize bean context
library;

import 'package:tom_core_server/tom_core_server.dart';

// =============================================================================
// Environment Initializers (like 02_environment_initialization.dart)
// =============================================================================

/// Development environment initializer.
/// In a real app, this would configure log levels, API endpoints, etc.
void initializeDev(TomEnvironment env) {
  // Configure development settings
  RuntimeInitializationExample.initializerCalls.add('dev');
  RuntimeInitializationExample.configuredLogLevel = 'development';
  RuntimeInitializationExample.configuredEndpoint = 'http://localhost:9080/';
}

/// Production environment initializer.
void initializeProd(TomEnvironment env) {
  // Configure production settings
  RuntimeInitializationExample.initializerCalls.add('prod');
  RuntimeInitializationExample.configuredLogLevel = 'production';
  RuntimeInitializationExample.configuredEndpoint = 'https://api.myapp.com/';
}

/// Integration environment initializer.
void initializeInt(TomEnvironment env) {
  // Configure integration settings
  RuntimeInitializationExample.initializerCalls.add('int');
  RuntimeInitializationExample.configuredLogLevel = 'extended';
  RuntimeInitializationExample.configuredEndpoint = 'https://int.myapp.com/';
}

// =============================================================================
// Environment Definitions (like 01_runtime_definition.dart)
// =============================================================================

/// Production environment - the root of the hierarchy.
const environmentProd = TomEnvironment(
  'prod',
  initializer: initializeProd,
);

/// Integration environment - child of prod, used for integration testing.
const environmentInt = TomEnvironment(
  'int',
  parent: environmentProd,
  isTest: true,
  initializer: initializeInt,
);

/// Development environment - child of prod, used for local development.
const environmentDev = TomEnvironment(
  'dev',
  parent: environmentProd,
  isDevelopment: true,
  isTest: true,
  initializer: initializeDev,
);

// =============================================================================
// Example Class
// =============================================================================

class RuntimeInitializationExample {
  // Track initializer calls
  static List<String> initializerCalls = [];
  static String? configuredLogLevel;
  static String? configuredEndpoint;

  // Captured results
  static late String envValue;
  static late String platformType;
  static late String currentEnvName;
  static late bool isDevelopment;
  static late bool isTest;
  static late List<String> hierarchyEnvs;

  // -------------------------------------------------------------------------
  // Step 1: Set environment variables
  // -------------------------------------------------------------------------
  static void step1SetEnvironmentVariables() {
    // Set environment to "dev" (as in main_dev.dart)
    TomPlatformUtils.envVars["env"] = "dev";
    TomPlatformUtils.envVars["useRemoteLogging"] = "false";
    TomPlatformUtils.envVars["apiBaseUrl"] = "http://localhost:9080/";

    envValue = TomPlatformUtils.envVars["env"]!;

    assert(TomPlatformUtils.envVars["env"] == "dev");
    assert(TomPlatformUtils.envVars["useRemoteLogging"] == "false");
  }

  // -------------------------------------------------------------------------
  // Step 2: Set platform utilities
  // -------------------------------------------------------------------------
  static void step2SetPlatformUtilities() {
    // For server/CLI apps, use TomStandalonePlatformUtils
    TomPlatformUtils.setCurrentPlatform(TomStandalonePlatformUtils());

    platformType = TomPlatformUtils.current.runtimeType.toString();

    assert(TomPlatformUtils.current is TomStandalonePlatformUtils);
  }

  // -------------------------------------------------------------------------
  // Step 3: Initialize runtime (combines multiple setup steps)
  // -------------------------------------------------------------------------
  static void step3InitializeRuntime() {
    // Register all environments
    TomRuntime.addEnvironment(environmentProd);
    TomRuntime.addEnvironment(environmentInt);
    TomRuntime.addEnvironment(environmentDev);

    // Set prod as the root (ultimate fallback)
    TomRuntime.setRootEnvironment(environmentProd);

    // Set current environment from envVars with fallback to "prod"
    TomRuntime.setCurrentEnvironment(
      TomPlatformUtils.current.getTomEnvVars()["env"],
      "prod",
    );

    // Run the environment initializer
    TomRuntime.getCurrentEnvironment().initialize();

    // Initialize platform detection
    TomRuntime.initializePlatform();

    // Capture results
    final currentEnv = TomRuntime.getCurrentEnvironment();
    currentEnvName = currentEnv.env;
    isDevelopment = currentEnv.isDevelopment;
    isTest = currentEnv.isTest;

    assert(currentEnvName == "dev");
    assert(isDevelopment == true);
    assert(isTest == true);
    assert(initializerCalls.contains('dev'));
  }

  // -------------------------------------------------------------------------
  // Step 4: Verify runtime state
  // -------------------------------------------------------------------------
  static void step4VerifyRuntimeState() {
    final currentEnv = TomRuntime.getCurrentEnvironment();
    final platform = TomRuntime.getCurrentPlatform();

    // Verify environment is correctly set
    final envName = currentEnv.env;
    final parentEnvName = currentEnv.parent?.env;

    // Verify platform is detected
    final platformName = platform?.name;
    final isDesktopPlatform = platformName == "macos" ||
        platformName == "linux" ||
        platformName == "windows";

    assert(envName == "dev");
    assert(parentEnvName == "prod");
    assert(platform != null);
    assert(isDesktopPlatform);
  }

  // -------------------------------------------------------------------------
  // Step 5: Get environment hierarchy
  // -------------------------------------------------------------------------
  static List<String> step5GetEnvironmentHierarchy() {
    final hierarchy = TomRuntime.getEnvironmentHierarchy();
    hierarchyEnvs = hierarchy.map((e) => e.env).toList();

    assert(hierarchy.length == 2); // prod -> dev
    assert(hierarchyEnvs.first == "prod");
    assert(hierarchyEnvs.last == "dev");

    return hierarchyEnvs;
  }

  // -------------------------------------------------------------------------
  // Step 6: Get runtime report
  // -------------------------------------------------------------------------
  static String step6GetRuntimeReport() {
    final report = TomRuntime.printReport();
    assert(report.isNotEmpty);
    return report;
  }

  // -------------------------------------------------------------------------
  // Run all steps
  // -------------------------------------------------------------------------
  static void run() {
    // Reset state for clean run
    initializerCalls.clear();
    configuredLogLevel = null;
    configuredEndpoint = null;

    print('=== 03: Runtime Initialization Sequence Example ===\n');

    print('1. Setting environment variables:');
    step1SetEnvironmentVariables();
    print('   - env: $envValue');
    print('   - useRemoteLogging: ${TomPlatformUtils.envVars["useRemoteLogging"]}');
    print('   - apiBaseUrl: ${TomPlatformUtils.envVars["apiBaseUrl"]}');

    print('\n2. Setting platform utilities:');
    step2SetPlatformUtilities();
    print('   - Platform type: $platformType');

    print('\n3. Initializing runtime:');
    step3InitializeRuntime();
    print('   - Initializer called for: ${initializerCalls.join(", ")}');
    print('   - Configured log level: $configuredLogLevel');
    print('   - Configured endpoint: $configuredEndpoint');
    print('   - Current environment: $currentEnvName');
    print('   - Is development: $isDevelopment');
    print('   - Is test: $isTest');

    print('\n4. Verifying runtime state:');
    step4VerifyRuntimeState();
    final platform = TomRuntime.getCurrentPlatform();
    print('   - Platform detected: ${platform?.name}');
    print('   - Parent environment: ${TomRuntime.getCurrentEnvironment().parent?.env}');

    print('\n5. Environment hierarchy (root to current):');
    final hierarchy = step5GetEnvironmentHierarchy();
    for (var envName in hierarchy) {
      // Find environment flags from hierarchy
      final envFromHierarchy = TomRuntime.getEnvironmentHierarchy()
          .where((e) => e.env == envName)
          .firstOrNull;
      final markers = <String>[];
      if (envFromHierarchy?.isDevelopment ?? false) markers.add('dev');
      if (envFromHierarchy?.isTest ?? false) markers.add('test');
      final markerStr = markers.isEmpty ? '' : ' [${markers.join(", ")}]';
      print('   - $envName$markerStr');
    }

    print('\n6. Runtime diagnostic report:');
    final report = step6GetRuntimeReport();
    print('   $report');

    print('\n=== All assertions passed! ===\n');
  }
}

void run() {
  RuntimeInitializationExample.run();
}
