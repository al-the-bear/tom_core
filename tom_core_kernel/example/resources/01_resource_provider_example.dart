/// Demonstrates resource provider usage for managing text resources and
/// configuration values in applications.
///
/// This example covers:
/// - TomTextResourceProvider for localized strings and UI labels
/// - TomConfigResourceProvider for application settings and configuration
/// - Different initialization patterns (from map, loader function, singleton)
/// - Hierarchical key access using dot notation
/// - Resource existence checking
/// - Fallback behavior for missing resources
///
/// These providers are particularly useful for:
/// - Internationalization (i18n) and localization (l10n)
/// - Environment-specific configuration management
/// - Centralized text resource management
/// - Feature flags and application settings
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

void run() {
  print('=== 01: Resource Provider Example ===\n');

  // ===========================================================================
  // Example 1: Creating TomTextResourceProvider from Map
  // ===========================================================================

  print('1. Creating text resource provider from a map:');

  final textResources = TomTextResourceProvider.from({
    'app': {
      'title': 'My Application',
      'version': '1.0.0',
      'description': 'A sample application',
    },
    'messages': {
      'welcome': 'Welcome to our app!',
      'goodbye': 'Thank you for using our app!',
      'errors': {
        'notFound': 'Resource not found',
        'unauthorized': 'You are not authorized',
      },
    },
    'buttons': {
      'submit': 'Submit',
      'cancel': 'Cancel',
      'save': 'Save Changes',
    },
  });

  final appTitle = textResources.getText('app.title');
  final appVersion = textResources.getText('app.version');
  final welcomeMessage = textResources.getText('messages.welcome');
  final notFoundError = textResources.getText('messages.errors.notFound');
  final submitButton = textResources.getText('buttons.submit');

  print('   app.title: $appTitle');
  print('   app.version: $appVersion');
  print('   messages.welcome: $welcomeMessage');
  print('   messages.errors.notFound: $notFoundError');
  print('   buttons.submit: $submitButton');
  print('');

  // ===========================================================================
  // Example 2: Using Loader Function Pattern
  // ===========================================================================

  print('2. Using loader function for lazy initialization:');

  // Simulate loading from a JSON file or API
  Map<String, dynamic> simulateJsonLoad() {
    return {
      'labels': {
        'username': 'Username',
        'password': 'Password',
        'email': 'Email Address',
      },
      'validation': {
        'required': 'This field is required',
        'invalidEmail': 'Please enter a valid email',
        'minLength': 'Must be at least 8 characters',
      },
    };
  }

  final loadedResources = TomTextResourceProvider.load(simulateJsonLoad);

  final usernameLabel = loadedResources.getText('labels.username');
  final requiredValidation = loadedResources.getText('validation.required');
  final invalidEmailMsg = loadedResources.getText('validation.invalidEmail');

  print('   Loaded using TomTextResourceProvider.load():');
  print('   labels.username: $usernameLabel');
  print('   validation.required: $requiredValidation');
  print('   validation.invalidEmail: $invalidEmailMsg');
  print('');

  // ===========================================================================
  // Example 3: Checking Resource Existence
  // ===========================================================================

  print('3. Checking if resources exist before accessing:');

  final existsAppTitle = textResources.exists('app.title');
  final existsAppIcon = textResources.exists('app.icon');
  final existsWelcome = textResources.exists('messages.welcome');
  final existsMissing = textResources.exists('nonexistent.path');

  print('   exists(app.title): $existsAppTitle');
  print('   exists(app.icon): $existsAppIcon');
  print('   exists(messages.welcome): $existsWelcome');
  print('   exists(nonexistent.path): $existsMissing');
  print('');

  // ===========================================================================
  // Example 4: Fallback Behavior for Missing Keys
  // ===========================================================================

  print('4. Fallback behavior when key is not found:');

  final missingKey = 'path.that.does.not.exist';
  final missingValue = textResources.getText(missingKey);
  final anotherMissing = textResources.getText('ui.header.logo');

  print('   Requesting: $missingKey');
  print('   Returns key itself: $missingValue');
  print('   Requesting: ui.header.logo');
  print('   Returns key itself: $anotherMissing');
  print('   (This helps identify missing resources during development)');
  print('');

  // ===========================================================================
  // Example 5: TomConfigResourceProvider for Configuration
  // ===========================================================================

  print('5. Creating configuration provider for app settings:');

  final configProvider = TomConfigResourceProvider.from({
    'api': {
      'baseUrl': 'https://api.example.com',
      'timeout': 30000,
      'retryCount': 3,
    },
    'features': {
      'darkMode': true,
      'analytics': false,
      'experimental': {
        'newUI': true,
        'betaFeatures': false,
      },
    },
    'limits': {
      'maxUploadSize': 10485760,
      'maxConnections': 100,
    },
  });

  final apiBaseUrl = configProvider.getText('api.baseUrl');
  final apiTimeout = configProvider.getText('api.timeout');
  final retryCount = configProvider.getText('api.retryCount');
  final darkModeEnabled = configProvider.getText('features.darkMode');
  final analyticsEnabled = configProvider.getText('features.analytics');
  final newUIEnabled = configProvider.getText('features.experimental.newUI');

  print('   api.baseUrl: $apiBaseUrl');
  print('   api.timeout: $apiTimeout (type: ${apiTimeout.runtimeType})');
  print('   api.retryCount: $retryCount (type: ${retryCount.runtimeType})');
  print('   features.darkMode: $darkModeEnabled');
  print('   features.analytics: $analyticsEnabled');
  print('   features.experimental.newUI: $newUIEnabled');
  print('');

  // ===========================================================================
  // Example 6: Config Provider with Loader Pattern
  // ===========================================================================

  print('6. Configuration provider with loader function:');

  Map<String, dynamic> loadEnvironmentConfig() {
    // Simulate loading environment-specific config
    return {
      'environment': 'development',
      'debug': true,
      'logging': {
        'level': 'debug',
        'toFile': false,
        'maxFiles': 5,
      },
      'database': {
        'host': 'localhost',
        'port': 5432,
        'name': 'dev_database',
      },
    };
  }

  final envConfig = TomConfigResourceProvider.load(loadEnvironmentConfig);

  final environment = envConfig.getText('environment');
  final debugMode = envConfig.getText('debug');
  final logLevel = envConfig.getText('logging.level');
  final dbHost = envConfig.getText('database.host');
  final dbPort = envConfig.getText('database.port');

  print('   environment: $environment');
  print('   debug: $debugMode');
  print('   logging.level: $logLevel');
  print('   database.host: $dbHost');
  print('   database.port: $dbPort');
  print('');

  // ===========================================================================
  // Example 7: Checking Configuration Existence
  // ===========================================================================

  print('7. Checking configuration key existence:');

  final existsApiTimeout = configProvider.exists('api.timeout');
  final existsApiKey = configProvider.exists('api.key');
  final existsFeatures = configProvider.exists('features.darkMode');
  final existsExperimental = configProvider.exists('features.experimental');

  print('   exists(api.timeout): $existsApiTimeout');
  print('   exists(api.key): $existsApiKey');
  print('   exists(features.darkMode): $existsFeatures');
  print('   exists(features.experimental): $existsExperimental');
  print('');

  // ===========================================================================
  // Example 8: Flat Key Access (Non-Nested)
  // ===========================================================================

  print('8. Flat key access without dot notation:');

  final flatResources = TomTextResourceProvider.from({
    'title': 'Flat Title',
    'description': 'Flat Description',
    'copyright': '© 2026 Example Corp',
  });

  final flatTitle = flatResources.getText('title');
  final flatDescription = flatResources.getText('description');
  final flatCopyright = flatResources.getText('copyright');
  final flatExistsTitle = flatResources.exists('title');
  final flatExistsMissing = flatResources.exists('author');

  print('   title: $flatTitle');
  print('   description: $flatDescription');
  print('   copyright: $flatCopyright');
  print('   exists(title): $flatExistsTitle');
  print('   exists(author): $flatExistsMissing');
  print('');

  // ===========================================================================
  // Example 9: Mixed Value Types in Configuration
  // ===========================================================================

  print('9. Configuration with mixed value types:');

  final mixedConfig = TomConfigResourceProvider.from({
    'stringValue': 'Hello World',
    'intValue': 42,
    'doubleValue': 3.14159,
    'boolValue': true,
    'listValue': ['a', 'b', 'c'],
    'nested': {
      'mapValue': {'key1': 'value1', 'key2': 'value2'},
    },
  });

  final stringVal = mixedConfig.getText('stringValue');
  final intVal = mixedConfig.getText('intValue');
  final doubleVal = mixedConfig.getText('doubleValue');
  final boolVal = mixedConfig.getText('boolValue');
  final listVal = mixedConfig.getText('listValue');
  final mapVal = mixedConfig.getText('nested.mapValue');

  print('   stringValue: $stringVal (${stringVal.runtimeType})');
  print('   intValue: $intVal (${intVal.runtimeType})');
  print('   doubleValue: $doubleVal (${doubleVal.runtimeType})');
  print('   boolValue: $boolVal (${boolVal.runtimeType})');
  print('   listValue: $listVal (${listVal.runtimeType})');
  print('   nested.mapValue: $mapVal (${mapVal.runtimeType})');
  print('');

  // ===========================================================================
  // Example 10: Direct Map Access
  // ===========================================================================

  print('10. Direct access to underlying resources map:');

  final directAccess = TomTextResourceProvider.from({
    'ui': {
      'theme': 'light',
      'language': 'en',
    },
  });

  final resourcesMap = directAccess.resources;
  final hasUiKey = resourcesMap.containsKey('ui');
  final uiSection = resourcesMap['ui'] as Map<String, dynamic>;
  final themeValue = uiSection['theme'];

  print('   resources map type: ${resourcesMap.runtimeType}');
  print('   contains "ui" key: $hasUiKey');
  print('   ui section: $uiSection');
  print('   ui.theme (direct): $themeValue');
  print('');

  // ===========================================================================
  // Assertions
  // ===========================================================================

  // Example 1: Creating TomTextResourceProvider from Map
  assert(appTitle == 'My Application');
  assert(appVersion == '1.0.0');
  assert(welcomeMessage == 'Welcome to our app!');
  assert(notFoundError == 'Resource not found');
  assert(submitButton == 'Submit');

  // Example 2: Using Loader Function Pattern
  assert(usernameLabel == 'Username');
  assert(requiredValidation == 'This field is required');
  assert(invalidEmailMsg == 'Please enter a valid email');

  // Example 3: Checking Resource Existence
  assert(existsAppTitle == true);
  assert(existsAppIcon == false);
  assert(existsWelcome == true);
  assert(existsMissing == false);

  // Example 4: Fallback Behavior for Missing Keys
  assert(missingValue == missingKey); // Returns key when not found
  assert(anotherMissing == 'ui.header.logo');

  // Example 5: TomConfigResourceProvider for Configuration
  assert(apiBaseUrl == 'https://api.example.com');
  assert(apiTimeout == 30000);
  assert(retryCount == 3);
  assert(darkModeEnabled == true);
  assert(analyticsEnabled == false);
  assert(newUIEnabled == true);

  // Example 6: Config Provider with Loader Pattern
  assert(environment == 'development');
  assert(debugMode == true);
  assert(logLevel == 'debug');
  assert(dbHost == 'localhost');
  assert(dbPort == 5432);

  // Example 7: Checking Configuration Existence
  assert(existsApiTimeout == true);
  assert(existsApiKey == false);
  assert(existsFeatures == true);
  assert(existsExperimental == true);

  // Example 8: Flat Key Access
  assert(flatTitle == 'Flat Title');
  assert(flatDescription == 'Flat Description');
  assert(flatCopyright == '© 2026 Example Corp');
  assert(flatExistsTitle == true);
  assert(flatExistsMissing == false);

  // Example 9: Mixed Value Types in Configuration
  assert(stringVal == 'Hello World');
  assert(intVal == 42);
  assert(doubleVal == 3.14159);
  assert(boolVal == true);
  assert(listVal is List);
  assert((listVal as List).length == 3);
  assert(mapVal is Map);

  // Example 10: Direct Map Access
  assert(hasUiKey == true);
  assert(themeValue == 'light');
  assert(uiSection['language'] == 'en');
}
