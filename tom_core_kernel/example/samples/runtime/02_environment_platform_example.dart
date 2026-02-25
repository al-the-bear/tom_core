/// Demonstrates environment and platform configuration using TomRuntime.
library;

import 'package:tom_core_server/tom_core_server.dart';

// =============================================================================
// Environment Initializers
// =============================================================================

int initializerCallCount = 0;
String? lastInitializedEnv;

void devInitializer(TomEnvironment env) {
  initializerCallCount++;
  lastInitializedEnv = env.env;
}

void prodInitializer(TomEnvironment env) {
  initializerCallCount++;
  lastInitializedEnv = env.env;
}

// =============================================================================
// EXAMPLE 1: Defining Custom Environments
// =============================================================================

class CustomEnvironmentsExample {
  static String? baseEnvName;
  static String? devEnvName;
  static String? devParentName;
  static bool environmentsWork = false;

  static void example1CustomEnvironments() {
    const baseEnv = TomEnvironment('base');
    const devEnv = TomEnvironment(
      'development',
      parent: baseEnv,
      isDevelopment: true,
    );

    baseEnvName = baseEnv.env;
    devEnvName = devEnv.env;
    devParentName = devEnv.parent?.env;

    environmentsWork =
        baseEnvName == 'base' &&
        devEnvName == 'development' &&
        devParentName == 'base' &&
        devEnv.isDevelopment == true;

    assert(baseEnvName == 'base', 'Base env name should match');
    assert(devEnvName == 'development', 'Dev env name should match');
    assert(devParentName == 'base', 'Dev parent should be base');
    assert(environmentsWork, 'Environments should work');
  }
}

// =============================================================================
// EXAMPLE 2: Environment Initializers
// =============================================================================

class EnvironmentInitializerExample {
  static int initCountBefore = 0;
  static int initCountAfter = 0;
  static bool initializerWorks = false;

  static void example2EnvironmentInitializer() {
    initializerCallCount = 0;

    final envWithInit = TomEnvironment(
      'custom-init',
      initializer: devInitializer,
    );

    initCountBefore = initializerCallCount;
    envWithInit.initialize();
    initCountAfter = initializerCallCount;

    initializerWorks = initCountBefore == 0 && initCountAfter == 1;

    assert(initCountBefore == 0, 'Init count before should be 0');
    assert(initCountAfter == 1, 'Init count after should be 1');
    assert(initializerWorks, 'Initializer should work');
  }
}

// =============================================================================
// EXAMPLE 3: Built-in Platform Constants
// =============================================================================

class PlatformConstantsExample {
  static String? webName;
  static String? macosName;
  static String? androidName;
  static bool constantsExist = false;

  static void example3PlatformConstants() {
    webName = platformWeb.name;
    macosName = platformMacos.name;
    androidName = platformAndroid.name;

    constantsExist =
        webName != null && macosName != null && androidName != null;

    assert(webName == 'web', 'Web platform name should match');
    assert(macosName == 'macos', 'macOS platform name should match');
    assert(androidName == 'android', 'Android platform name should match');
    assert(constantsExist, 'Platform constants should exist');
  }
}

// =============================================================================
// EXAMPLE 4: Setting Up Runtime
// =============================================================================

class RuntimeSetupExample {
  static String? currentEnvName;
  static bool? isDevelopment;
  static bool runtimeWorks = false;

  static void example4RuntimeSetup() {
    // Define environments
    const prodEnv = TomEnvironment('prod');
    const devEnv = TomEnvironment(
      'dev',
      parent: prodEnv,
      isDevelopment: true,
    );

    // Register environments
    TomRuntime.addEnvironment(prodEnv);
    TomRuntime.addEnvironment(devEnv);

    // Set current environment
    TomRuntime.setCurrentEnvironment('dev');

    // Set platform utils
    TomPlatformUtils.setCurrentPlatform(TomStandalonePlatformUtils());

    // Initialize platform detection
    TomRuntime.initializePlatform();

    currentEnvName = TomRuntime.getCurrentEnvironment().env;
    isDevelopment = TomRuntime.getCurrentEnvironment().isDevelopment;

    runtimeWorks = currentEnvName == 'dev' && isDevelopment == true;

    assert(currentEnvName == 'dev', 'Current env should be dev');
    assert(isDevelopment == true, 'Should be development mode');
    assert(runtimeWorks, 'Runtime setup should work');
  }
}

// =============================================================================
// EXAMPLE 5: Environment Hierarchy
// =============================================================================

class EnvironmentHierarchyExample {
  static int hierarchyLength = 0;
  static List<String> hierarchyEnvs = [];
  static bool hierarchyWorks = false;

  static void example5EnvironmentHierarchy() {
    final hierarchy = TomRuntime.getEnvironmentHierarchy();

    hierarchyLength = hierarchy.length;
    hierarchyEnvs = hierarchy.map((e) => e.env).toList();

    hierarchyWorks = hierarchyLength >= 1;

    assert(hierarchyLength >= 1, 'Hierarchy should have at least one env');
    assert(hierarchyWorks, 'Hierarchy should work');
  }
}

// =============================================================================
// EXAMPLE 6: Runtime Report
// =============================================================================

class RuntimeReportExample {
  static String? report;
  static bool reportNotEmpty = false;

  static void example6RuntimeReport() {
    report = TomRuntime.printReport();
    reportNotEmpty = report != null && report!.isNotEmpty;

    assert(reportNotEmpty, 'Report should not be empty');
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

void run() {
  CustomEnvironmentsExample.example1CustomEnvironments();
  EnvironmentInitializerExample.example2EnvironmentInitializer();
  PlatformConstantsExample.example3PlatformConstants();
  RuntimeSetupExample.example4RuntimeSetup();
  EnvironmentHierarchyExample.example5EnvironmentHierarchy();
  RuntimeReportExample.example6RuntimeReport();
}

void main() => run();
