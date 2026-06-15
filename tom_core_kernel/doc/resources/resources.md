# Resources Module

The Resources module provides singleton-based resource management for applications, enabling centralized access to text resources (localized strings, UI labels) and configuration values (settings, feature flags).

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Core Components](#core-components)
- [Best Practices](#best-practices)
- [Dependencies](#dependencies)

---

## Overview

The module consists of two main providers:

| Provider | Purpose | Value Types |
|----------|---------|-------------|
| `TomTextResourceProvider` | Localized strings, UI labels, messages | Strings only |
| `TomConfigResourceProvider` | Application settings, feature flags | Any type |

Both providers share similar patterns:
- **Singleton access** for application-wide resource sharing
- **Hierarchical key access** using dot notation (e.g., `'app.settings.theme'`)
- **Lazy initialization** with optional loader functions
- **Fallback behavior** returning the key when a resource is not found

## Quick Start

### 1. Set Up Text Resources

```dart
import 'package:tom_core/src/tombase/resources/tom_resource_provider.dart';

// Option A: Define a loader function (recommended for JSON assets)
TomTextResourceProvider.loader = () => {
  'app': {
    'title': 'My Application',
    'version': '1.0.0',
  },
  'messages': {
    'welcome': 'Welcome to the app!',
    'goodbye': 'See you later!',
  },
};

// Option B: Create from an existing map
final provider = TomTextResourceProvider.from({
  'greeting': 'Hello, World!',
});
TomTextResourceProvider.setAppResourceProvider(provider);
```

### 2. Access Text Resources

```dart
// Get the singleton instance
final resources = TomTextResourceProvider.getAppResources();

// Retrieve text values
String title = resources.getText('app.title');           // 'My Application'
String welcome = resources.getText('messages.welcome');  // 'Welcome to the app!'

// Check if a resource exists
if (resources.exists('messages.optional')) {
  showMessage(resources.getText('messages.optional'));
}

// Missing resources return the key itself
String missing = resources.getText('unknown.key');       // 'unknown.key'
```

### 3. Set Up Configuration

```dart
// Define configuration loader
TomConfigResourceProvider.loader = () => {
  'api': {
    'baseUrl': 'https://api.example.com',
    'timeout': 30000,
  },
  'features': {
    'darkMode': true,
    'analytics': false,
    'maxItems': 100,
  },
};
```

### 4. Access Configuration

```dart
final config = TomConfigResourceProvider.getAppConfig();

// Retrieve typed configuration values
String apiUrl = config.getText('api.baseUrl') as String;   // 'https://api.example.com'
int timeout = config.getText('api.timeout') as int;        // 30000
bool darkMode = config.getText('features.darkMode') as bool; // true

// Check if configuration exists
if (config.exists('features.experimental')) {
  enableExperimentalFeatures();
}
```

### 5. Easy client integration

Use a simple extension like this to make text resources and configuration available anywhere

```dart
import 'package:tom_core/tom_core.dart';
import '../sample_app_state.dart';

extension TomResourceExtension on Object {
  String Function(String) get t =>
      TomTextResourceProvider.getAppResources().getText;
  bool Function(String) get translationExists =>
      TomTextResourceProvider.getAppResources().exists;
  Object Function(String) get c =>
      TomConfigResourceProvider.getAppConfig().getText;
  bool Function(String) get configExists =>
      TomConfigResourceProvider.getAppConfig().exists;

  //TODO: add method to get configuration as int, double and bool
}
```

You find this file in the UAM sample application.

## Core Components

### TomTextResourceProvider

A singleton provider for text-based resources.

#### Static Members

| Member | Type | Description |
|--------|------|-------------|
| `loader` | `Map<String, dynamic> Function()?` | Optional function to load resources lazily |
| `setAppResourceProvider()` | Method | Sets the application-wide provider instance |
| `getAppResources()` | Method | Returns the singleton provider instance |

#### Constructors

| Constructor | Description |
|-------------|-------------|
| `TomTextResourceProvider()` | Creates provider using static `loader` if set |
| `TomTextResourceProvider.load(loader)` | Creates provider with a custom loader function |
| `TomTextResourceProvider.from(map)` | Creates provider from an existing map |

#### Instance Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `exists(key)` | `bool` | Checks if a **String** value exists at the path |
| `existsObject(key)` | `bool` | Checks if **any** value (of any type) exists at the path |
| `getText(key)` | `String` | Returns the text value, or the **key itself** if not found |
| `getTextOrNull(key)` | `String?` | Returns the text value (Strings only), or **`null`** if not found |
| `getObject(key)` | `Object` | Returns the value (any type), or the **key itself** if not found |
| `getObjectOrNull(key)` | `Object?` | Returns the value (any type), or **`null`** if not found |

### TomConfigResourceProvider

A singleton provider for configuration values of any type.

#### Static Members

| Member | Type | Description |
|--------|------|-------------|
| `loader` | `Map<String, dynamic> Function()?` | Optional function to load configuration lazily |
| `setAppConfigProvider()` | Method | Sets the application-wide provider instance |
| `getAppConfig()` | Method | Returns the singleton provider instance |

#### Constructors

| Constructor | Description |
|-------------|-------------|
| `TomConfigResourceProvider()` | Creates provider using static `loader` if set |
| `TomConfigResourceProvider.load(loader)` | Creates provider with a custom loader function |
| `TomConfigResourceProvider.from(map)` | Creates provider from an existing map |

#### Instance Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `exists(key)` | `bool` | Checks if any value exists at the path |
| `getText(key)` | `Object` | Returns the value (any type), or the **key itself** if not found |

> **Note:** `TomConfigResourceProvider.getText` returns `Object` (callers cast,
> e.g. `config.getText('api.timeout') as int`). The object/`OrNull` accessors
> (`getObject`, `getObjectOrNull`, `existsObject`, `getTextOrNull`) live on
> [`TomTextResourceProvider`](#tomtextresourceprovider), not here.

### Fallback: key vs. null

The `getText` / `getObject` accessors return the **lookup key itself** when a
resource is missing. This is convenient during development — an unresolved key
renders visibly instead of crashing — but it means "missing" and "the value
happens to equal the key" are indistinguishable. When you need to branch on
presence (rather than render a placeholder), prefer the `OrNull` variants:

```dart
final resources = TomTextResourceProvider.getAppResources();

// Placeholder behaviour — shows the key when missing.
String label = resources.getText('screens.home.title');

// Presence behaviour — null when missing.
String? optional = resources.getTextOrNull('screens.home.subtitle');
if (optional != null) showSubtitle(optional);

// On the text provider, getObjectOrNull avoids the exists()+get double lookup.
final retries = resources.getObjectOrNull('api.retries') as int? ?? 3;

// The config provider has no OrNull accessor — guard with exists() before casting.
final config = TomConfigResourceProvider.getAppConfig();
final timeout = config.exists('api.timeout') ? config.getText('api.timeout') as int : 5000;
```

## Usage Examples

### Loading Resources from JSON Assets

```dart
import 'dart:convert';
import 'package:flutter/services.dart';

Future<void> initializeResources() async {
  // Load text resources from assets
  TomTextResourceProvider.loader = () {
    final jsonString = await rootBundle.loadString('assets/strings.json');
    return jsonDecode(jsonString) as Map<String, dynamic>;
  };
  
  // Load configuration from assets
  TomConfigResourceProvider.loader = () {
    final jsonString = await rootBundle.loadString('assets/config.json');
    return jsonDecode(jsonString) as Map<String, dynamic>;
  };
}
```

### Environment-Specific Configuration

```dart
void setupEnvironment(String environment) {
  final configs = {
    'dev': {
      'api': {'baseUrl': 'https://dev.api.example.com', 'debug': true},
    },
    'prod': {
      'api': {'baseUrl': 'https://api.example.com', 'debug': false},
    },
  };
  
  TomConfigResourceProvider.setAppConfigProvider(
    TomConfigResourceProvider.from(configs[environment]!),
  );
}
```

### Localization Support

```dart
class LocalizationService {
  void setLocale(String locale) {
    final localizedStrings = loadStringsForLocale(locale);
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(localizedStrings),
    );
  }
  
  String translate(String key) {
    return TomTextResourceProvider.getAppResources().getText(key);
  }
}
```

### Feature Flags

```dart
class FeatureFlags {
  static bool isEnabled(String feature) {
    final config = TomConfigResourceProvider.getAppConfig();
    if (config.exists('features.$feature')) {
      return config.getText('features.$feature') as bool;
    }
    return false;
  }
}

// Usage
if (FeatureFlags.isEnabled('newCheckout')) {
  showNewCheckoutFlow();
} else {
  showLegacyCheckoutFlow();
}
```

## Best Practices

### 1. Initialize Early

Set up resource providers during application initialization, before any UI code attempts to access resources:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize resources first
  await initializeResources();
  
  runApp(MyApp());
}
```

### 2. Use Hierarchical Keys

Organize resources with meaningful hierarchical keys for better maintainability:

```dart
// Good: Organized hierarchy
'screens.home.title'
'screens.home.welcomeMessage'
'errors.network.timeout'
'errors.network.noConnection'

// Avoid: Flat, unclear keys
'homeTitle'
'welcomeMsg'
'timeoutError'
```

### 3. Handle Missing Resources Gracefully

The providers return the key when a resource is not found. Use this for debugging but handle missing resources appropriately in production:

```dart
String getRequiredText(String key) {
  final resources = TomTextResourceProvider.getAppResources();
  final value = resources.getText(key);
  
  if (value == key) {
    // Log missing resource in development
    assert(() {
      print('Warning: Missing resource key: $key');
      return true;
    }());
  }
  
  return value;
}
```

### 4. Type Safety for Configuration

Cast configuration values to their expected types and handle type mismatches:

```dart
T getConfig<T>(String key, T defaultValue) {
  final config = TomConfigResourceProvider.getAppConfig();
  
  if (!config.exists(key)) {
    return defaultValue;
  }
  
  final value = config.getText(key);
  if (value is T) {
    return value;
  }
  
  return defaultValue;
}

// Usage
final timeout = getConfig<int>('api.timeout', 5000);
final debugMode = getConfig<bool>('debug.enabled', false);
```

### 5. Avoid Reloading in Production

The singleton pattern means resources are loaded once. If you need to update resources at runtime (e.g., for locale changes), explicitly set a new provider:

```dart
void updateLocale(String newLocale) {
  final newResources = loadResourcesForLocale(newLocale);
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(newResources),
  );
}
```

## Architecture Notes

### Singleton Pattern

Both providers use the singleton pattern with lazy initialization. The first call to `getAppResources()` or `getAppConfig()` creates the instance, which is then reused for all subsequent calls.

### Hierarchical Access

Resources support dot-notation access (e.g., `'app.settings.theme'`) through the `getObjectFromTree` function from the JSON utilities module. This allows for organized, nested resource structures.

---

## Dependencies

This module depends on:

- **JSON Module**: `getObjectFromTree` function for hierarchical key access
