/// Demonstrates resource provider usage for managing text resources and
/// configuration values.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

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

    assert(environment == 'development', 'Environment should be development');
    assert(logLevel == 'debug', 'Log level should be debug');
    assert(configLoaderWorks, 'Config loader should work');
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

void run() {
  TextResourceFromMapExample.example1TextResourceFromMap();
  LoaderFunctionExample.example2LoaderFunction();
  ResourceExistenceExample.example3ResourceExistence();
  FallbackBehaviorExample.example4FallbackBehavior();
  ConfigResourceExample.example5ConfigResource();
  ConfigLoaderExample.example6ConfigLoader();
}

void main() => run();
