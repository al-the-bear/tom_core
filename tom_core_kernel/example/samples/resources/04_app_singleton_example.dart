/// Demonstrates the application-wide singleton surface of both resource
/// providers. Examples 01 through 03 build providers with `.from()` and
/// `.load()` and read from those instances directly — none of them installs
/// one, so nothing they build is reachable by code that was not handed the
/// reference. This example is about the other half.
///
/// This example covers:
/// - The static `loader` field driving the default constructor
///   (`TomTextResourceProvider()` / `TomConfigResourceProvider()`)
/// - Installing the singleton with `setAppResourceProvider()` /
///   `setAppConfigProvider()`
/// - Reading it back with `getAppResources()` / `getAppConfig()`
/// - Singleton identity (the same instance is returned on repeat access)
/// - The two providers holding fully independent singletons
///
/// The singleton pattern lets application code configure resources once, at
/// startup, and then read them from anywhere without threading a provider
/// reference through the call graph.
///
/// Installation is explicit and mandatory: `getAppResources()` throws
/// `resources.text_provider.not_installed` until `setAppResourceProvider()` has
/// run, and setting `loader` alone does not install anything — it says how to
/// build a bundle, not when to put one in place. That is what keeps
/// `appResourcesRevision` honest: every installed bundle went through the one
/// call that bumps the counter.
///
/// `loader` is synchronous (`Map<String, dynamic> Function()`), because
/// `getText` is: the bundle has to be in memory before the first read. It
/// therefore suits bundles that can be produced without awaiting, as below. An
/// asynchronous source — a JSON asset, a file, a download — is awaited in
/// `main()` first and installed with `.from(...)`; see
/// `doc/resources/resources.md`.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_asserts.dart';

void run() {
  print('=== 04: App Singleton Example ===\n');

  // ===========================================================================
  // Example 1: loader drives the default constructor
  // ===========================================================================

  print('1. Static loader drives the default constructor:');

  TomTextResourceProvider.loader = () => {
    'app': {'title': 'Loaded App'},
  };
  // The default constructor consults the static loader when one is set.
  final loadedText = TomTextResourceProvider();
  final loadedTitle = loadedText.getText('app.title');

  print(
    '   TomTextResourceProvider.loader set, then TomTextResourceProvider()',
  );
  print('   app.title: $loadedTitle');
  print('');

  // ===========================================================================
  // Example 2: installing a loader-built provider, then reading it back
  // ===========================================================================

  print('2. Install a loader-built provider, then getAppResources() reads it:');

  // Installing is what makes the bundle app-wide; getAppResources() only reads
  // back what was installed, and throws if that never happened.
  TomTextResourceProvider.setAppResourceProvider(TomTextResourceProvider());
  final appText = TomTextResourceProvider.getAppResources();
  final appTitleAgain = TomTextResourceProvider.getAppResources();
  final appTitleValue = appText.getText('app.title');
  final sameTextSingleton = identical(appText, appTitleAgain);

  print('   getAppResources().getText("app.title"): $appTitleValue');
  print('   getAppResources() returns the same instance: $sameTextSingleton');
  print('');

  // ===========================================================================
  // Example 3: setAppResourceProvider replaces the singleton
  // ===========================================================================

  print('3. setAppResourceProvider() replaces the app-wide instance:');

  final custom = TomTextResourceProvider.from({
    'app': {'title': 'Custom App'},
  });
  TomTextResourceProvider.setAppResourceProvider(custom);
  final customTitle = TomTextResourceProvider.getAppResources().getText(
    'app.title',
  );
  final isCustomInstance = identical(
    TomTextResourceProvider.getAppResources(),
    custom,
  );

  print('   after setAppResourceProvider(custom):');
  print('   getAppResources().getText("app.title"): $customTitle');
  print('   getAppResources() is the custom instance: $isCustomInstance');
  print('');

  // ===========================================================================
  // Example 4: TomConfigResourceProvider carries its own independent singleton
  // ===========================================================================

  print('4. Config provider has its own loader and singleton:');

  TomConfigResourceProvider.loader = () => {
    'api': {'timeout': 30000},
  };
  TomConfigResourceProvider.setAppConfigProvider(TomConfigResourceProvider());
  final appConfig = TomConfigResourceProvider.getAppConfig();
  final timeout = appConfig.getText('api.timeout');
  final sameConfigSingleton = identical(
    appConfig,
    TomConfigResourceProvider.getAppConfig(),
  );

  print('   getAppConfig().getText("api.timeout"): $timeout');
  print('   getAppConfig() returns the same instance: $sameConfigSingleton');
  print('');

  // ===========================================================================
  // Example 5: the two singletons are fully independent
  // ===========================================================================

  print('5. Text and config singletons do not interfere:');

  final textStillCustom = TomTextResourceProvider.getAppResources().getText(
    'app.title',
  );
  final configStillTimeout = TomConfigResourceProvider.getAppConfig().getText(
    'api.timeout',
  );

  print('   text singleton app.title: $textStillCustom');
  print('   config singleton api.timeout: $configStillTimeout');
  print('');

  // Reset static loaders so this example leaves no global state behind for a
  // subsequent example run in the same process.
  TomTextResourceProvider.loader = null;
  TomConfigResourceProvider.loader = null;

  // ===========================================================================
  // Assertions
  // ===========================================================================

  // Example 1: loader-driven default constructor
  assert(loadedTitle == 'Loaded App');

  // Example 2: installed loader-built singleton + identity
  assert(appTitleValue == 'Loaded App');
  assert(sameTextSingleton);

  // Example 3: singleton replacement
  assert(customTitle == 'Custom App');
  assert(isCustomInstance);

  // Example 4: config singleton
  assert(timeout == 30000);
  assert(sameConfigSingleton);

  // Example 5: independence
  assert(textStillCustom == 'Custom App');
  assert(configStillTimeout == 30000);
}

/// Standalone entry point.
void main() {
  requireAsserts();
  run();
}
