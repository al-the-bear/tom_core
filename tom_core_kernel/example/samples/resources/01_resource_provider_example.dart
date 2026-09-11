/// Demonstrates resource provider usage for managing text resources and
/// configuration values.
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/resources/01_resource_provider_example.dart
/// ```
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

// =============================================================================
// EXAMPLE 1: Creating TomTextResourceProvider from Map
// =============================================================================

class TextResourceFromMapExample {
  static String? appTitle;
  static String? welcomeMessage;
  static String? nestedError;

  static void example1TextResourceFromMap() {
    final textResources = TomTextResourceProvider.from({
      'app': {'title': 'My Application', 'version': '1.0.0'},
      'messages': {
        'welcome': 'Welcome to our app!',
        'errors': {'notFound': 'Resource not found'},
      },
    });

    appTitle = textResources.getText('app.title');
    welcomeMessage = textResources.getText('messages.welcome');
    nestedError = textResources.getText('messages.errors.notFound');

    print('1. Reading nested text out of a map:');
    print('   getText("app.title"): $appTitle');
    print('   getText("messages.welcome"): $welcomeMessage');
    print('   getText("messages.errors.notFound"): $nestedError');
    print('');

    assert(appTitle == 'My Application', 'App title should match');
    assert(
      welcomeMessage == 'Welcome to our app!',
      'Welcome message should match',
    );
    assert(nestedError == 'Resource not found', 'Nested error should match');
  }
}

// =============================================================================
// EXAMPLE 2: Using Loader Function Pattern
// =============================================================================

class LoaderFunctionExample {
  static String? usernameLabel;
  static String? requiredValidation;
  static int loaderCalls = 0;

  static void example2LoaderFunction() {
    Map<String, dynamic> simulateJsonLoad() {
      loaderCalls++;
      return {
        'labels': {'username': 'Username', 'password': 'Password'},
        'validation': {'required': 'This field is required'},
      };
    }

    final loadedResources = TomTextResourceProvider.load(simulateJsonLoad);

    usernameLabel = loadedResources.getText('labels.username');
    requiredValidation = loadedResources.getText('validation.required');

    print('2. Building a provider from a loader function:');
    print('   getText("labels.username"): $usernameLabel');
    print('   getText("validation.required"): $requiredValidation');
    print('');

    assert(usernameLabel == 'Username', 'Username label should match');
    assert(
      requiredValidation == 'This field is required',
      'Validation message should match',
    );
    // The loader runs once, in the constructor, and never again: `getText` is
    // synchronous and reads the map that call produced. A provider that
    // re-invoked the loader per lookup would re-parse the bundle on every
    // label, which is exactly what this constructor exists to avoid.
    assert(loaderCalls == 1, 'The loader should run exactly once, eagerly');
  }
}

// =============================================================================
// EXAMPLE 3: Checking Resource Existence
// =============================================================================

class ResourceExistenceExample {
  static bool existsAppTitle = false;
  static bool existsMissing = false;
  static bool existenceChecksWork = false;

  static void example3ResourceExistence() {
    final textResources = TomTextResourceProvider.from({
      'app': {'title': 'My App'},
    });

    existsAppTitle = textResources.exists('app.title');
    existsMissing = textResources.exists('nonexistent.path');

    existenceChecksWork = existsAppTitle && !existsMissing;

    print('3. Checking whether a key exists:');
    print('   exists("app.title"): $existsAppTitle');
    print('   exists("nonexistent.path"): $existsMissing');
    print('');

    assert(existsAppTitle, 'app.title should exist');
    assert(!existsMissing, 'nonexistent.path should not exist');
    assert(existenceChecksWork, 'Existence checks should work');
  }
}

// =============================================================================
// EXAMPLE 4: Fallback Behavior for Missing Keys
// =============================================================================

class FallbackBehaviorExample {
  static String? missingKeyValue;
  static bool fallbackReturnsKey = false;

  static void example4FallbackBehavior() {
    final textResources = TomTextResourceProvider.from({
      'app': {'title': 'My App'},
    });

    final missingKey = 'path.that.does.not.exist';
    missingKeyValue = textResources.getText(missingKey);

    // When key is missing, the key itself is returned
    fallbackReturnsKey = missingKeyValue == missingKey;

    print('4. Fallback for a missing key:');
    print('   getText("$missingKey"): "$missingKeyValue" (the key itself)');
    print('');

    assert(
      missingKeyValue == missingKey,
      'Missing key should return the key itself',
    );
    assert(fallbackReturnsKey, 'Fallback behavior should work');
  }
}

// =============================================================================
// EXAMPLE 5: TomConfigResourceProvider for Configuration
// =============================================================================

class ConfigResourceExample {
  static String? apiBaseUrl;
  static String? apiTimeout;
  static String? darkModeEnabled;

  static void example5ConfigResource() {
    final configProvider = TomConfigResourceProvider.from({
      'api': {'baseUrl': 'https://api.example.com', 'timeout': 30000},
      'features': {'darkMode': true},
    });

    // getObjectOrNull, not getObject: on a miss getObject echoes the key back
    // as a String, so `as String?` would hand the key text over as the URL.
    apiBaseUrl = configProvider.getObjectOrNull('api.baseUrl') as String?;
    apiTimeout = configProvider.getObject('api.timeout').toString();
    darkModeEnabled = configProvider.getObject('features.darkMode').toString();

    print('5. TomConfigResourceProvider for configuration values:');
    print('   getObjectOrNull("api.baseUrl"): $apiBaseUrl');
    print('   getObject("api.timeout"): $apiTimeout');
    print('   getObject("features.darkMode"): $darkModeEnabled');
    print('');

    assert(
      apiBaseUrl == 'https://api.example.com',
      'API base URL should match',
    );
    assert(apiTimeout == '30000', 'API timeout should be string');
    assert(darkModeEnabled == 'true', 'Dark mode should be string');
  }
}

// =============================================================================
// EXAMPLE 6: Config Provider with Loader Pattern
// =============================================================================

class ConfigLoaderExample {
  static String? environment;
  static String? logLevel;
  static bool configLoaderWorks = false;

  static void example6ConfigLoader() {
    Map<String, dynamic> loadEnvironmentConfig() {
      return {
        'environment': 'development',
        'logging': {'level': 'debug'},
      };
    }

    final envConfig = TomConfigResourceProvider.load(loadEnvironmentConfig);

    environment = envConfig.getObjectOrNull('environment') as String?;
    logLevel = envConfig.getObjectOrNull('logging.level') as String?;

    configLoaderWorks = environment == 'development' && logLevel == 'debug';

    print('6. Config provider built from a loader function:');
    print('   getObjectOrNull("environment"): $environment');
    print('   getObjectOrNull("logging.level"): $logLevel');
    print('');

    assert(environment == 'development', 'Environment should be development');
    assert(logLevel == 'debug', 'Log level should be debug');
    assert(configLoaderWorks, 'Config loader should work');
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

void run() {
  print('=== 01: Resource Provider Example ===\n');

  TextResourceFromMapExample.example1TextResourceFromMap();
  LoaderFunctionExample.example2LoaderFunction();
  ResourceExistenceExample.example3ResourceExistence();
  FallbackBehaviorExample.example4FallbackBehavior();
  ConfigResourceExample.example5ConfigResource();
  ConfigLoaderExample.example6ConfigLoader();
}

/// Standalone entry point.
void main() {
  prepareSampleProcess();
  run();
}
