/// Advanced Runtime Example
///
/// This example demonstrates advanced runtime features:
/// - getEnvironmentHierarchy for parent chain
/// - Platform initializers
/// - Environment/platform matching for beans
/// - Runtime diagnostic report
/// - Environment fallback behavior
/// - noTomEnvironment and noTomPlatform sentinels
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_asserts.dart';

// ============================================================================
// Platform Initializer Tracking
// ============================================================================

int platformInitCount = 0;
String? lastInitializedPlatform;

void trackingPlatformInitializer(TomPlatform platform, TomEnvironment? env) {
  platformInitCount++;
  lastInitializedPlatform = platform.name;
}

// ============================================================================
// Example Class
// ============================================================================

class AdvancedRuntimeExample {
  // Captured results
  static List<String>? hierarchyNames;
  static bool hierarchyWorks = false;
  static bool diagnosticWorks = false;
  static bool platformInitWorks = false;
  static bool fallbackWorks = false;
  static bool sentinelsWork = false;

  // --------------------------------------------------------------------------
  // Example 1: Environment hierarchy
  // --------------------------------------------------------------------------
  static void example1EnvironmentHierarchy() {
    print('1. Environment hierarchy with getEnvironmentHierarchy:');

    // Create a chain of environments
    const rootEnv = TomEnvironment('root');
    const parentEnv = TomEnvironment('parent', parent: rootEnv);
    const currentEnv = TomEnvironment('current', parent: parentEnv);

    // Clear and register environments
    TomRuntime.addEnvironment(rootEnv);
    TomRuntime.addEnvironment(parentEnv);
    TomRuntime.addEnvironment(currentEnv);

    // Set current
    TomRuntime.setCurrentEnvironment('current');

    // Get the full hierarchy
    final hierarchy = TomRuntime.getEnvironmentHierarchy();

    hierarchyNames = hierarchy.map((e) => e.env).toList();
    print('   - Created: root -> parent -> current');
    print('   - getEnvironmentHierarchy(): $hierarchyNames');
    print('   - First (root): ${hierarchy.first.env}');
    print('   - Last (current): ${hierarchy.last.env}');

    hierarchyWorks =
        hierarchyNames!.length == 3 &&
        hierarchyNames![0] == 'root' &&
        hierarchyNames![2] == 'current';

    // Assertions
    assert(hierarchyWorks, 'Hierarchy should include all environments');
  }

  // --------------------------------------------------------------------------
  // Example 2: Runtime diagnostic report
  // --------------------------------------------------------------------------
  static void example2DiagnosticReport() {
    print('\n2. Runtime diagnostic report:');

    final report = TomRuntime.printReport();
    print('   - TomRuntime.printReport():');
    print('     $report');

    diagnosticWorks =
        report.contains('TomRuntime') &&
        report.contains('Platform') &&
        report.contains('Environment');

    // Assertions
    assert(diagnosticWorks, 'Report should contain runtime info');
  }

  // --------------------------------------------------------------------------
  // Example 3: Platform initializers
  // --------------------------------------------------------------------------
  static void example3PlatformInitializers() {
    print('\n3. Platform initializers:');

    // Reset tracking
    platformInitCount = 0;

    // Create a custom platform and set initializer
    final customPlatform = TomPlatform('custom-platform');
    customPlatform.setInitializer(trackingPlatformInitializer);

    print('   - Created custom platform with initializer');
    print('   - platformInitCount before: $platformInitCount');

    // Run the initializer
    customPlatform.initializePlatform(null);

    print('   - platformInitCount after: $platformInitCount');
    print('   - lastInitializedPlatform: $lastInitializedPlatform');

    platformInitWorks =
        platformInitCount == 1 && lastInitializedPlatform == 'custom-platform';

    // Assertions
    assert(platformInitWorks, 'Platform initializer should run');
  }

  // --------------------------------------------------------------------------
  // Example 4: Environment fallback behavior
  // --------------------------------------------------------------------------
  static void example4EnvironmentFallback() {
    print('\n4. Environment fallback behavior:');

    // Register known environments
    const prodEnv = TomEnvironment('production');
    const devEnv = TomEnvironment('development', isDevelopment: true);
    TomRuntime.addEnvironment(prodEnv);
    TomRuntime.addEnvironment(devEnv);

    // Set with fallback to defaultRoot
    TomRuntime.setCurrentEnvironment('nonexistent', 'defaultRoot');
    var current = TomRuntime.getCurrentEnvironment();
    print('   - Set "nonexistent" with fallback "defaultRoot"');
    print('   - Result: ${current.env}');

    // Set with named fallback
    TomRuntime.setCurrentEnvironment('missing', 'development');
    current = TomRuntime.getCurrentEnvironment();
    print('   - Set "missing" with fallback "development"');
    print('   - Result: ${current.env}');

    fallbackWorks = current.env == 'development';

    // Assertions
    assert(fallbackWorks, 'Fallback should work');
  }

  // --------------------------------------------------------------------------
  // Example 5: noTomEnvironment and noTomPlatform sentinels
  // --------------------------------------------------------------------------
  static void example5Sentinels() {
    print('\n5. noTomEnvironment and noTomPlatform sentinels:');

    print('   - noTomEnvironment.env: "${noTomEnvironment.env}"');
    print('   - noTomPlatform.name: "${noTomPlatform.name}"');
    print('');
    print('   Purpose:');
    print('   - Used in bean annotations to indicate "no constraint"');
    print('   - Bean matches any environment/platform when annotated');
    print('');
    print('   Example:');
    print('   @TomComponent(MyService)');
    print('   @noTomEnvironment  // Works in any environment');
    print('   @noTomPlatform     // Works on any platform');
    print('   class DefaultMyService implements MyService {}');

    sentinelsWork =
        noTomEnvironment.env == 'none' && noTomPlatform.name == 'none';

    // Assertions
    assert(sentinelsWork, 'Sentinels should have correct names');
  }

  // --------------------------------------------------------------------------
  // Example 6: TomEnvironment properties
  // --------------------------------------------------------------------------
  static void example6EnvironmentProperties() {
    print('\n6. TomEnvironment properties:');

    const prodEnv = TomEnvironment('production');
    const devEnv = TomEnvironment('dev', isDevelopment: true);
    const testEnv = TomEnvironment('test', isTest: true);

    print('   Production:');
    print('   - isDevelopment: ${prodEnv.isDevelopment}');
    print('   - isTest: ${prodEnv.isTest}');

    print('   Development:');
    print('   - isDevelopment: ${devEnv.isDevelopment}');
    print('   - isTest: ${devEnv.isTest}');

    print('   Test:');
    print('   - isDevelopment: ${testEnv.isDevelopment}');
    print('   - isTest: ${testEnv.isTest}');

    // Assertions
    assert(prodEnv.isDevelopment == false, 'Prod not dev');
    assert(devEnv.isDevelopment == true, 'Dev is dev');
    assert(testEnv.isTest == true, 'Test is test');
  }

  // --------------------------------------------------------------------------
  // Example 7: Available platforms
  // --------------------------------------------------------------------------
  static void example7AvailablePlatforms() {
    print('\n7. Available platform constants:');

    final platforms = [
      platformWeb,
      platformMacos,
      platformWindows,
      platformAndroid,
      platformIos,
      platformLinux,
      platformFuchsia,
    ];

    print('   Built-in platform constants:');
    for (final platform in platforms) {
      print('   - ${platform.name}');
    }

    // Check current platform
    final current = TomRuntime.getCurrentPlatform();
    print('');
    print('   Current platform: ${current?.name ?? "not set"}');
  }

  // --------------------------------------------------------------------------
  // Example 8: Environment toString
  // --------------------------------------------------------------------------
  static void example8EnvironmentToString() {
    print('\n8. Environment and Platform toString:');

    const envWithParent = TomEnvironment(
      'child',
      parent: defaultTomEnvironment,
    );

    print('   - defaultTomEnvironment.toString():');
    print('     ${defaultTomEnvironment.toString()}');
    print('   - envWithParent.toString():');
    print('     ${envWithParent.toString()}');
    print('   - platformLinux.toString():');
    print('     ${platformLinux.toString()}');
  }

  // --------------------------------------------------------------------------
  // Example 9: Bean selection with environment/platform
  // --------------------------------------------------------------------------
  static void example9BeanSelection() {
    print('\n9. Bean selection with environment/platform:');

    print('''
   Use annotations to control bean selection:
   
   // Development-only bean
   @TomComponent(MyService)
   @TomEnvironment('development')
   class DevMyService implements MyService {}
   
   // Production bean
   @TomComponent(MyService)
   @TomEnvironment('production')
   class ProdMyService implements MyService {}
   
   // iOS-specific bean
   @TomComponent(Storage)
   @platformIos
   class IosStorage implements Storage {}
   
   // Android-specific bean
   @TomComponent(Storage)
   @platformAndroid
   class AndroidStorage implements Storage {}
   
   // Environment + Platform specific
   @TomComponent(Logger)
   @TomEnvironment('development')
   @platformWeb
   class WebDevLogger implements Logger {}
''');
  }

  // --------------------------------------------------------------------------
  // Example 10: Root environment
  // --------------------------------------------------------------------------
  static void example10RootEnvironment() {
    print('10. Root environment:');

    final root = TomRuntime.getRoot();
    print('   - TomRuntime.getRoot(): ${root.env}');

    print('');
    print('   Setting custom root:');
    print('   TomRuntime.setRootEnvironment(myRootEnv);');
    print('');
    print('   The root environment is the ultimate fallback');
    print('   when no matching environment is found.');
  }
}

// ============================================================================
// Run Function
// ============================================================================

void run() {
  print('=== 04: Advanced Runtime Example ===\n');

  // Clear the process-global environment/platform registries so this sample
  // starts from a clean runtime — the master samples runner executes every
  // module in one process, so a prior sample's registrations would otherwise
  // leak in and shadow the environments registered here.
  TomRuntime.reset();
  AdvancedRuntimeExample.example1EnvironmentHierarchy();
  AdvancedRuntimeExample.example2DiagnosticReport();
  AdvancedRuntimeExample.example3PlatformInitializers();
  AdvancedRuntimeExample.example4EnvironmentFallback();
  AdvancedRuntimeExample.example5Sentinels();
  AdvancedRuntimeExample.example6EnvironmentProperties();
  AdvancedRuntimeExample.example7AvailablePlatforms();
  AdvancedRuntimeExample.example8EnvironmentToString();
  AdvancedRuntimeExample.example9BeanSelection();
  AdvancedRuntimeExample.example10RootEnvironment();

  // Final assertions
  assert(AdvancedRuntimeExample.hierarchyWorks, 'Hierarchy should work');
  assert(AdvancedRuntimeExample.diagnosticWorks, 'Diagnostic should work');
  assert(AdvancedRuntimeExample.platformInitWorks, 'Platform init should work');
  assert(AdvancedRuntimeExample.sentinelsWork, 'Sentinels should work');

  print('\n✓ All advanced runtime examples passed!\n');
}

void main() {
  requireAsserts();
  run();
}
