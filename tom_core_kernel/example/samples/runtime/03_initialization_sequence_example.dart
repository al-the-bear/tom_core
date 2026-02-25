/// Demonstrates the complete runtime initialization sequence.
library;

import 'package:tom_core_server/tom_core_server.dart';

// =============================================================================
// Environment Initializers
// =============================================================================

List<String> initializerCalls = [];
String? configuredLogLevel;
String? configuredEndpoint;

void initializeDev(TomEnvironment env) {
  initializerCalls.add('dev');
  configuredLogLevel = 'development';
  configuredEndpoint = 'http://localhost:9080/';
}

void initializeProd(TomEnvironment env) {
  initializerCalls.add('prod');
  configuredLogLevel = 'production';
  configuredEndpoint = 'https://api.myapp.com/';
}

// =============================================================================
// Environment Definitions
// =============================================================================

const environmentProd = TomEnvironment(
  'prod',
  initializer: initializeProd,
);

const environmentDev = TomEnvironment(
  'dev',
  parent: environmentProd,
  isDevelopment: true,
  isTest: true,
  initializer: initializeDev,
);

// =============================================================================
// EXAMPLE 1: Set Environment Variables
// =============================================================================

class SetEnvVarsExample {
  static String? envValue;
  static bool envVarsSet = false;

  static void example1SetEnvVars() {
    TomPlatformUtils.envVars['env'] = 'dev';
    TomPlatformUtils.envVars['useRemoteLogging'] = 'false';
    TomPlatformUtils.envVars['apiBaseUrl'] = 'http://localhost:9080/';

    envValue = TomPlatformUtils.envVars['env'];
    envVarsSet = envValue == 'dev';

    assert(TomPlatformUtils.envVars['env'] == 'dev', 'Env should be dev');
    assert(envVarsSet, 'Env vars should be set');
  }
}

// =============================================================================
// EXAMPLE 2: Set Platform Utilities
// =============================================================================

class SetPlatformUtilsExample {
  static String? platformType;
  static bool platformSet = false;

  static void example2SetPlatformUtilities() {
    TomPlatformUtils.setCurrentPlatform(TomStandalonePlatformUtils());

    platformType = TomPlatformUtils.current.runtimeType.toString();
    platformSet = TomPlatformUtils.current is TomStandalonePlatformUtils;

    assert(TomPlatformUtils.current is TomStandalonePlatformUtils, 'Should be standalone');
    assert(platformSet, 'Platform should be set');
  }
}

// =============================================================================
// EXAMPLE 3: Initialize Runtime
// =============================================================================

class InitializeRuntimeExample {
  static String? currentEnvName;
  static bool? isDevelopment;
  static bool? isTest;
  static bool runtimeInitialized = false;

  static void example3InitializeRuntime() {
    initializerCalls.clear();

    // Register environments
    TomRuntime.addEnvironment(environmentProd);
    TomRuntime.addEnvironment(environmentDev);

    // Set root environment
    TomRuntime.setRootEnvironment(environmentProd);

    // Set current environment from envVars with fallback
    TomRuntime.setCurrentEnvironment(
      TomPlatformUtils.current.getTomEnvVars()['env'],
      'prod',
    );

    // Run the initializer
    TomRuntime.getCurrentEnvironment().initialize();

    // Initialize platform detection
    TomRuntime.initializePlatform();

    final currentEnv = TomRuntime.getCurrentEnvironment();
    currentEnvName = currentEnv.env;
    isDevelopment = currentEnv.isDevelopment;
    isTest = currentEnv.isTest;

    runtimeInitialized =
        currentEnvName == 'dev' &&
        isDevelopment == true &&
        initializerCalls.contains('dev');

    assert(currentEnvName == 'dev', 'Current env should be dev');
    assert(isDevelopment == true, 'Should be development');
    assert(runtimeInitialized, 'Runtime should be initialized');
  }
}

// =============================================================================
// EXAMPLE 4: Verify Runtime State
// =============================================================================

class VerifyRuntimeStateExample {
  static String? envName;
  static String? parentEnvName;
  static String? platformName;
  static bool stateVerified = false;

  static void example4VerifyRuntimeState() {
    final currentEnv = TomRuntime.getCurrentEnvironment();
    final platform = TomRuntime.getCurrentPlatform();

    envName = currentEnv.env;
    parentEnvName = currentEnv.parent?.env;
    platformName = platform?.name;

    stateVerified =
        envName == 'dev' &&
        parentEnvName == 'prod' &&
        platform != null;

    assert(envName == 'dev', 'Env should be dev');
    assert(parentEnvName == 'prod', 'Parent should be prod');
    assert(platform != null, 'Platform should be detected');
    assert(stateVerified, 'State should be verified');
  }
}

// =============================================================================
// EXAMPLE 5: Get Environment Hierarchy
// =============================================================================

class GetHierarchyExample {
  static List<String> hierarchyEnvs = [];
  static int hierarchyLength = 0;
  static bool hierarchyCorrect = false;

  static void example5GetHierarchy() {
    final hierarchy = TomRuntime.getEnvironmentHierarchy();

    hierarchyEnvs = hierarchy.map((e) => e.env).toList();
    hierarchyLength = hierarchy.length;

    hierarchyCorrect =
        hierarchyLength == 2 &&
        hierarchyEnvs.first == 'prod' &&
        hierarchyEnvs.last == 'dev';

    assert(hierarchyLength == 2, 'Hierarchy should have 2 envs');
    assert(hierarchyEnvs.first == 'prod', 'First should be prod');
    assert(hierarchyEnvs.last == 'dev', 'Last should be dev');
    assert(hierarchyCorrect, 'Hierarchy should be correct');
  }
}

// =============================================================================
// EXAMPLE 6: Get Runtime Report
// =============================================================================

class GetRuntimeReportExample {
  static String? report;
  static bool reportNotEmpty = false;

  static void example6GetRuntimeReport() {
    report = TomRuntime.printReport();
    reportNotEmpty = report != null && report!.isNotEmpty;

    assert(reportNotEmpty, 'Report should not be empty');
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

void run() {
  SetEnvVarsExample.example1SetEnvVars();
  SetPlatformUtilsExample.example2SetPlatformUtilities();
  InitializeRuntimeExample.example3InitializeRuntime();
  VerifyRuntimeStateExample.example4VerifyRuntimeState();
  GetHierarchyExample.example5GetHierarchy();
  GetRuntimeReportExample.example6GetRuntimeReport();
}

void main() => run();
