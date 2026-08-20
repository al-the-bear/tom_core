/// Demonstrates resource provider usage for managing text resources and
/// configuration values.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_asserts.dart';

// =============================================================================
// EXAMPLE 1: Creating TomTextResourceProvider from Map
// =============================================================================

class TextResourceFromMapExample {
  static String? appTitle;
  static String? welcomeMessage;
  static String? nestedError;
  static bool resourcesLoaded = false;

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
    resourcesLoaded = true;

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
    assert(resourcesLoaded, 'Resources should be loaded');
  }
}

// =============================================================================
// EXAMPLE 2: Using Loader Function Pattern
// =============================================================================

class LoaderFunctionExample {
  static String? usernameLabel;
  static String? requiredValidation;
  static bool loaderUsed = false;

  static void example2LoaderFunction() {
    Map<String, dynamic> simulateJsonLoad() {
      return {
        'labels': {'username': 'Username', 'password': 'Password'},
        'validation': {'required': 'This field is required'},
      };
    }

    final loadedResources = TomTextResourceProvider.load(simulateJsonLoad);

    usernameLabel = loadedResources.getText('labels.username');
    requiredValidation = loadedResources.getText('validation.required');
    loaderUsed = true;

    print('2. Building a provider from a loader function:');
    print('   getText("labels.username"): $usernameLabel');
    print('   getText("validation.required"): $requiredValidation');
    print('');

    assert(usernameLabel == 'Username', 'Username label should match');
    assert(
      requiredValidation == 'This field is required',
      'Validation message should match',
    );
    assert(loaderUsed, 'Loader should be used');
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
  static bool configLoaded = false;

  static void example5ConfigResource() {
    final configProvider = TomConfigResourceProvider.from({
      'api': {'baseUrl': 'https://api.example.com', 'timeout': 30000},
      'features': {'darkMode': true},
    });

    apiBaseUrl = configProvider.getText('api.baseUrl') as String?;
    apiTimeout = configProvider.getText('api.timeout').toString();
    darkModeEnabled = configProvider.getText('features.darkMode').toString();
    configLoaded = true;

    print('5. TomConfigResourceProvider for configuration values:');
    print('   getText("api.baseUrl"): $apiBaseUrl');
    print('   getText("api.timeout"): $apiTimeout');
    print('   getText("features.darkMode"): $darkModeEnabled');
    print('');

    assert(
      apiBaseUrl == 'https://api.example.com',
      'API base URL should match',
    );
    assert(apiTimeout == '30000', 'API timeout should be string');
    assert(darkModeEnabled == 'true', 'Dark mode should be string');
    assert(configLoaded, 'Config should be loaded');
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

    environment = envConfig.getText('environment') as String?;
    logLevel = envConfig.getText('logging.level') as String?;

    configLoaderWorks = environment == 'development' && logLevel == 'debug';

    print('6. Config provider built from a loader function:');
    print('   getText("environment"): $environment');
    print('   getText("logging.level"): $logLevel');
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
  requireAsserts();
  run();
}
